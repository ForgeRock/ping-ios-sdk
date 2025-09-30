//
//  LocationCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CoreLocation

// MARK: - LocationInfo

/// Geographic location information for the device.
///
/// This structure contains the device's current geographic coordinates
/// as determined by the location services system.
struct LocationInfo: Codable {
    /// Latitude coordinate in decimal degrees
    /// - Note: Positive values represent northern hemisphere, negative for southern
    /// - Range: -90.0 to +90.0 degrees
    let latitude: Double?
    
    /// Longitude coordinate in decimal degrees
    /// - Note: Positive values represent eastern hemisphere, negative for western
    /// - Range: -180.0 to +180.0 degrees
    let longitude: Double?
    
    /// Initializes location information with coordinate values
    /// - Parameters:
    ///   - latitude: Latitude in decimal degrees, nil if unavailable
    ///   - longitude: Longitude in decimal degrees, nil if unavailable
    init(latitude: Double?, longitude: Double?) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - LocationCollector

/// Collector for device geographic location information.
///
/// This collector attempts to determine the device's current location
/// using the LocationManager system. It handles authorization requests
/// and provides location data when available and permitted.
///
/// ## Privacy Considerations
/// - Requires location permissions from the user
/// - Respects user privacy settings and restrictions
/// - Returns nil if location access is denied or unavailable
///
/// ## Usage Requirements
/// - App must include location usage descriptions in Info.plist
/// - User must grant location permissions
/// - Location services must be enabled on device
class LocationCollector: NSObject, DeviceCollector {
    typealias DataType = LocationInfo
    
    /// Unique identifier for location data
    let key = "location"
    
    /// LocationManager instance for handling location requests
    /// - Note: Defaults to shared singleton, but can be injected for testing
    var locationManager: LocationManager
    
    /// Initializes the collector with optional dependency injection
    /// - Parameter locationManager: LocationManager instance (defaults to shared)
    init(locationManager: LocationManager = LocationManager.shared) {
        self.locationManager = locationManager
        super.init()
    }
    
    /// Collects current device location information
    /// - Returns: LocationInfo with coordinates, or nil if location unavailable
    ///
    /// ## Behavior
    /// - Requests location permission if not already granted
    /// - Uses cached location if recently obtained
    /// - Returns nil on permission denial or location failure
    /// - Handles all authorization states appropriately
    ///
    /// ## Error Handling
    /// - Catches and handles all location-related errors internally
    /// - Returns nil rather than throwing for unavailable location
    /// - Logs errors for debugging purposes
    func collect() async -> LocationInfo? {
        return await getCurrentLocation()
    }
    
    /// Attempts to get current device location
    /// - Returns: LocationInfo if successful, nil if failed or unauthorized
    ///
    /// ## Implementation Details
    /// - Uses the injected LocationManager instance
    /// - Handles all error cases gracefully
    /// - Converts CLLocation to LocationInfo structure
    /// - Maintains privacy by returning nil on denial
    private func getCurrentLocation() async -> LocationInfo? {
        do {
            // Attempt to request location from LocationManager
            if let location = try await locationManager.requestLocation() {
                return LocationInfo(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                // Location request succeeded but returned nil (should be rare)
                return nil
            }
        } catch {
            // Location request failed (permission denied, services disabled, etc.)
            // Return nil to indicate location is unavailable
            return nil
        }
    }
}
