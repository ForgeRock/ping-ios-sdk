//
//  LocationManager.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CoreLocation

// MARK: - LocationError

/// Errors that can occur during location operations.
///
/// These errors provide specific information about why location requests
/// might fail, allowing applications to respond appropriately to different
/// failure scenarios.
enum LocationError: Error, LocalizedError {
    /// Location services are disabled system-wide
    case locationServicesDisabled
    
    /// User has explicitly denied location access for this app
    case authorizationDenied
    
    /// Location access is restricted by system policies (parental controls, etc.)
    case authorizationRestricted
    
    /// Required privacy usage descriptions are missing from Info.plist
    case missingPrivacyConsent
    
    /// Location request failed with underlying CoreLocation error
    case locationFailed(Error)
    
    /// Human-readable error descriptions for debugging and user feedback
    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location services are disabled system-wide"
        case .authorizationDenied:
            return "Location authorization was denied by user"
        case .authorizationRestricted:
            return "Location authorization is restricted by system policy"
        case .missingPrivacyConsent:
            return "Missing required privacy usage description in Info.plist"
        case .locationFailed(let error):
            return "Failed to obtain location: \(error.localizedDescription)"
        }
    }
}

// MARK: - LocationManagerProtocol

/// Protocol wrapping CoreLocation functionality for dependency injection and testability
protocol LocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    
    static func locationServicesEnabled() -> Bool
    static func authorizationStatus() -> CLAuthorizationStatus
    
    func requestLocation() async
    func requestWhenInUseAuthorization() async
    func requestAlwaysAuthorization() async
}

// MARK: - CLLocationManager Conformance

extension CLLocationManager: LocationManagerProtocol {
    // CLLocationManager already implements all required methods
    // No additional code needed - this just makes it conform to the protocol
}


// MARK: - LocationManager

/// LocationManager is responsible for requesting authorization, managing, and collecting device location information.
///
/// This class provides a modern, async/await interface for location services built on top of
/// CoreLocation. It handles authorization requests, caching, error handling, and provides
/// both throwing and non-throwing interfaces for different use cases.
///
/// ## Features
/// - **Async/Await Interface**: Modern Swift concurrency support
/// - **Automatic Authorization**: Handles permission requests transparently
/// - **Location Caching**: Reduces battery usage with intelligent caching
/// - **Error Handling**: Comprehensive error reporting and recovery
/// - **Privacy Compliance**: Respects system privacy settings and user choices
///
/// ## Usage Example
/// ```swift
/// do {
///     let location = try await LocationManager.shared.requestLocation()
///     print("Current location: \(location?.coordinate)")
/// } catch {
///     print("Location failed: \(error)")
/// }
/// ```
///
/// ## Privacy Requirements
/// Your app's Info.plist must include appropriate usage descriptions:
/// - `NSLocationWhenInUseUsageDescription` for basic location access
/// - `NSLocationAlwaysAndWhenInUseUsageDescription` for background location access
public class LocationManager: NSObject, ObservableObject, @unchecked Sendable {
    
    // MARK: - Constants
    
    /// Shared singleton instance of LocationManager for app-wide coordination
    @MainActor
    public static let shared = LocationManager()
    
    /// Duration in seconds for which cached location data remains valid
    /// This prevents excessive location requests and preserves battery life
    static let locationCacheValidityInSeconds: TimeInterval = 5
    
    // MARK: - Private Properties
    
    /// LocationManagerProtocol instance for system location services
    private let locationManager: LocationManagerProtocol
        
    /// LocationManagerProtocol concrete type
    private let locationManagerType: LocationManagerProtocol.Type
    
    /// Most recently obtained location with timestamp for cache validation
    private var lastKnownLocation: CLLocation?
    
    /// Continuation for the current location request (async/await support)
    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?
    
    /// Continuation for authorization request (async/await support)
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    // MARK: - Published Properties
    
    /// Whether a location request is currently in progress
    /// Useful for UI state management and preventing concurrent requests
    @Published private(set) var isRequesting = false
    
    // MARK: - Computed Properties
    
    /// Current authorization status using iOS 13+ compatible class method
    /// - Returns: Current location authorization status for the application
    var authorizationStatus: CLAuthorizationStatus {
        return locationManagerType.authorizationStatus()
    }
    
    /// Human-readable authorization status for debugging and logging
    /// - Returns: String representation of current authorization status
    var authorizationStatusString: String {
        switch authorizationStatus {
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Lifecycle
    
    /// Initializes LocationManager with dependency injection support
    /// - Parameters:
    ///   - locationManager: The location manager implementation (defaults to CLLocationManager)
    ///   - locationManagerType: The type for class methods (defaults to CLLocationManager.self)
    @MainActor
    init(locationManager: LocationManagerProtocol = CLLocationManager(),
         locationManagerType: LocationManagerProtocol.Type = CLLocationManager.self) {
        self.locationManager = locationManager
        self.locationManagerType = locationManagerType
        super.init()
        setupLocationManager()
    }
    
    /// Configures the location manager with optimal settings for device profiling
    @MainActor
    private func setupLocationManager() {
        // Use moderate accuracy to balance precision with battery life
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self
    }
    
    // MARK: - Public API
    
    /// Requests location information with automatic authorization handling.
    ///
    /// This method provides a complete location request workflow:
    /// 1. Checks if location services are enabled system-wide
    /// 2. Evaluates current authorization status
    /// 3. Requests authorization if needed
    /// 4. Fetches current location or returns cached location if still valid
    ///
    /// - Returns: CLLocation if successful, nil if location unavailable
    /// - Throws: LocationError for various failure scenarios
    ///
    /// ## Caching Behavior
    /// - Returns cached location if less than 5 seconds old
    /// - Requests fresh location for expired cache
    /// - Cache helps preserve battery life and reduces API calls
    ///
    /// ## Authorization Handling
    /// - Automatically requests permission for first-time users
    /// - Throws appropriate errors for denied or restricted access
    /// - Handles both "when in use" and "always" authorization types
    ///
    /// ## Example Usage
    /// ```swift
    /// do {
    ///     if let location = try await LocationManager.shared.requestLocation() {
    ///         let coords = location.coordinate
    ///         print("Lat: \(coords.latitude), Lng: \(coords.longitude)")
    ///     } else {
    ///         print("Location unavailable")
    ///     }
    /// } catch LocationError.authorizationDenied {
    ///     // Handle permission denial
    /// } catch LocationError.locationServicesDisabled {
    ///     // Handle system-wide location services disabled
    /// } catch {
    ///     // Handle other location errors
    /// }
    /// ```
    func requestLocation() async throws -> CLLocation? {
        // Update UI state on main actor
        await MainActor.run { isRequesting = true }
        
        defer {
            Task { @MainActor in
                isRequesting = false
            }
        }
        
        // Verify location services are enabled system-wide
        guard locationManagerType.locationServicesEnabled() else {
            throw LocationError.locationServicesDisabled
        }
        
        // Handle different authorization states
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Already authorized, fetch location
            return try await fetchLocationWithAuthorization()
            
        case .notDetermined:
            // Need to request authorization first
            let status = try await requestAuthorizationIfNeeded()
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                return try await fetchLocationWithAuthorization()
            } else {
                throw authorizationErrorForStatus(status)
            }
            
        case .denied:
            throw LocationError.authorizationDenied
            
        case .restricted:
            throw LocationError.authorizationRestricted
            
        @unknown default:
            throw LocationError.authorizationDenied
        }
    }
    
    /// Requests location information without throwing errors.
    ///
    /// This is a convenience method for cases where you want to attempt
    /// location access but don't need detailed error handling. Useful
    /// for optional location features or fire-and-forget scenarios.
    ///
    /// - Returns: CLLocation if successful, nil for any failure
    ///
    /// ## Use Cases
    /// - Optional location features that shouldn't interrupt user flow
    /// - Background location attempts where errors are logged but not handled
    /// - Fallback scenarios where location is nice-to-have but not required
    ///
    /// ## Example Usage
    /// ```swift
    /// let location = await LocationManager.shared.requestLocationSafe()
    /// if let coords = location?.coordinate {
    ///     // Use location data
    /// } else {
    ///     // Continue without location
    /// }
    /// ```
    func requestLocationSafe() async -> CLLocation? {
        do {
            return try await requestLocation()
        } catch {
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Fetches location when authorization is already granted
    /// - Returns: Current location or cached location if still valid
    /// - Throws: LocationError.locationFailed for CoreLocation errors
    private func fetchLocationWithAuthorization() async throws -> CLLocation? {
        // Return cached location if still valid (within cache validity period)
        if let lastLocation = lastKnownLocation,
           Date().timeIntervalSince(lastLocation.timestamp) < Self.locationCacheValidityInSeconds {
            return lastLocation
        }
        
        // Request fresh location from system
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                locationContinuation = continuation
                await locationManager.requestLocation()
            }
        }
    }
    
    /// Requests location authorization based on Info.plist configurations
    /// - Returns: Final authorization status after user interaction
    /// - Throws: LocationError.missingPrivacyConsent if required keys are missing
    private func requestAuthorizationIfNeeded() async throws -> CLAuthorizationStatus {
        // Check for required Info.plist privacy usage descriptions
        let hasAlwaysUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil
        let hasWhenInUseUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
        
        guard hasAlwaysUsageDescription || hasWhenInUseUsageDescription else {
            throw LocationError.missingPrivacyConsent
        }
        
        return await withCheckedContinuation { continuation in
            Task {
                authorizationContinuation = continuation
                
                // Request appropriate authorization level based on Info.plist configuration
                if hasAlwaysUsageDescription {
                    await locationManager.requestAlwaysAuthorization()
                } else if hasWhenInUseUsageDescription {
                    await locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    /// Converts authorization status to appropriate error
    /// - Parameter status: Authorization status to convert
    /// - Returns: Corresponding LocationError for the status
    private func authorizationErrorForStatus(_ status: CLAuthorizationStatus) -> LocationError {
        switch status {
        case .denied:
            return .authorizationDenied
        case .restricted:
            return .authorizationRestricted
        default:
            return .authorizationDenied
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: @preconcurrency CLLocationManagerDelegate {
    
    /// Called when the authorization status changes
    /// - Parameter manager: The location manager whose authorization changed
    /// - Parameter status: The new authorization status
    @MainActor
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Resume any pending authorization continuation
        if let continuation = authorizationContinuation {
            authorizationContinuation = nil
            continuation.resume(returning: status)
        }
    }
    
    /// Called when location data becomes available
    /// - Parameter manager: The location manager providing the update
    /// - Parameter locations: Array of location objects in chronological order
    @MainActor
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Cache the most recent location for future requests
        lastKnownLocation = location
        
        // Resume any pending location continuation with the new location
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location)
        }
    }
    
    /// Called when location request fails
    /// - Parameter manager: The location manager that encountered the error
    /// - Parameter error: The error that occurred during location request
    @MainActor
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Resume any pending location continuation with the error
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: LocationError.locationFailed(error))
        }
    }
}
