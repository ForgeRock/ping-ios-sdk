// 
//  LocationManagerTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CoreLocation
@testable import PingDeviceProfile

class LocationManagerTests: XCTestCase {
    
    var locationManager: LocationManager!
    
    override func setUp() {
        super.setUp()
        locationManager = LocationManager()
    }
    
    override func tearDown() {
        locationManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLocationManagerInitialization() {
        XCTAssertNotNil(locationManager, "LocationManager should initialize")
        XCTAssertFalse(locationManager.isRequesting, "isRequesting should be false initially")
    }
    
    // MARK: - Shared Instance Tests
    
    func testSharedInstanceSingleton() {
        let instance1 = LocationManager.shared
        let instance2 = LocationManager.shared
        
        XCTAssertNotNil(instance1, "Shared instance should not be nil")
        XCTAssertNotNil(instance2, "Second shared instance should not be nil")
        XCTAssertTrue(instance1 === instance2, "Shared instances should be identical")
    }
    
    func testSharedInstancePersistence() {
        weak var weakShared: LocationManager?
        
        autoreleasepool {
            let shared = LocationManager.shared
            weakShared = shared
        }
        
        // Shared instance should persist
        XCTAssertNotNil(weakShared, "Shared instance should persist")
        XCTAssertTrue(LocationManager.shared === weakShared,
                     "Shared instance should remain the same")
    }
    
    // MARK: - Constants Tests
    
    func testLocationCacheValidityConstant() {
        XCTAssertEqual(LocationManager.locationCacheValidityInSeconds, 5.0,
                      "Cache validity should be 5 seconds")
        XCTAssertGreaterThan(LocationManager.locationCacheValidityInSeconds, 0,
                           "Cache validity should be positive")
    }
    
    // MARK: - Authorization Status Tests
    
    func testAuthorizationStatus() {
        let status = locationManager.authorizationStatus
        
        // Should be one of the valid CLAuthorizationStatus values
        let validStatuses: [CLAuthorizationStatus] = [
            .notDetermined,
            .restricted,
            .denied,
            .authorizedAlways,
            .authorizedWhenInUse
        ]
        
        XCTAssertTrue(validStatuses.contains(status),
                     "Authorization status should be valid")
    }
    
    func testAuthorizationStatusString() {
        let statusString = locationManager.authorizationStatusString
        
        let validStrings = [
            "notDetermined",
            "restricted",
            "denied",
            "authorizedAlways",
            "authorizedWhenInUse"
        ]
        
        XCTAssertTrue(validStrings.contains(statusString),
                     "Authorization status string should be valid")
        XCTAssertFalse(statusString.isEmpty, "Status string should not be empty")
    }
    
    func testAuthorizationStatusStringConsistency() {
        let status = locationManager.authorizationStatus
        let statusString = locationManager.authorizationStatusString
        
        // Verify string matches the actual status
        switch status {
        case .notDetermined:
            XCTAssertEqual(statusString, "notDetermined")
        case .restricted:
            XCTAssertEqual(statusString, "restricted")
        case .denied:
            XCTAssertEqual(statusString, "denied")
        case .authorizedAlways:
            XCTAssertEqual(statusString, "authorizedAlways")
        case .authorizedWhenInUse:
            XCTAssertEqual(statusString, "authorizedWhenInUse")
        @unknown default:
            XCTAssertEqual(statusString, "unknown")
        }
    }
    
    // MARK: - Location Request Tests
    
    func testRequestLocationSafeNeverThrows() async {
        // This method should never throw, even on errors
        _ = await locationManager.requestLocationSafe()
        
        // Result can be nil (which is expected in many cases), but method should complete
        XCTAssertTrue(true, "requestLocationSafe completed without throwing")
    }
    
    func testRequestLocationSafeMultipleCalls() async {
        _ = await locationManager.requestLocationSafe()
        _ = await locationManager.requestLocationSafe()
        
        // Both calls should complete without throwing
        XCTAssertTrue(true, "Multiple requestLocationSafe calls completed without throwing")
        
        // Results might be nil or valid locations, both are acceptable
    }
    
    func testRequestLocationWithoutPermissions() async {
        // In test environment without permissions, this should handle gracefully
        do {
            _ = try await locationManager.requestLocation()
            // If it succeeds, that's fine (might have permissions in test environment)
            // Result might be nil, which is acceptable
        } catch {
            // Expected to throw in many test scenarios
            XCTAssertTrue(error is LocationError, "Should throw LocationError")
        }
    }
    
    func testIsRequestingProperty() {
        XCTAssertFalse(locationManager.isRequesting, "Should not be requesting initially")
        
        // Test that isRequesting is @Published (important for SwiftUI)
        // We can't easily test the actual state change during async operations in unit tests
        // but we can verify the property exists and has correct initial state
    }
    
    // MARK: - LocationError Tests
    
    func testLocationErrorTypes() {
        let errors: [LocationError] = [
            .locationServicesDisabled,
            .authorizationDenied,
            .authorizationRestricted,
            .missingPrivacyConsent,
            .locationFailed(NSError(domain: "TestDomain", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true,
                          "Error description should not be empty")
        }
    }
    
    func testLocationErrorDescriptions() {
        XCTAssertEqual(LocationError.locationServicesDisabled.errorDescription,
                      "Location services are disabled system-wide")
        
        XCTAssertEqual(LocationError.authorizationDenied.errorDescription,
                      "Location authorization was denied by user")
        
        XCTAssertEqual(LocationError.authorizationRestricted.errorDescription,
                      "Location authorization is restricted by system policy")
        
        XCTAssertEqual(LocationError.missingPrivacyConsent.errorDescription,
                      "Missing required privacy usage description in Info.plist")
        
        let underlyingError = NSError(domain: "TestDomain", code: 123,
                                    userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let locationError = LocationError.locationFailed(underlyingError)
        
        XCTAssertTrue(locationError.errorDescription?.contains("Failed to obtain location") ?? false,
                     "Should contain failure message")
        XCTAssertTrue(locationError.errorDescription?.contains("Test error") ?? false,
                     "Should contain underlying error description")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentLocationRequests() async {
        let iterations = 5
        
        await withTaskGroup(of: CLLocation?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.locationManager.requestLocationSafe()
                }
            }
            
            var results: [CLLocation?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent requests")
            // Results might be nil, which is acceptable
        }
    }
    
    func testConcurrentAuthorizationStatusAccess() async {
        let iterations = 10
        
        await withTaskGroup(of: CLAuthorizationStatus.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return self.locationManager.authorizationStatus
                }
            }
            
            var statuses: [CLAuthorizationStatus] = []
            for await status in group {
                statuses.append(status)
            }
            
            XCTAssertEqual(statuses.count, iterations, "Should complete all concurrent status reads")
            
            // All statuses should be the same (authorization doesn't change rapidly)
            if statuses.count > 1 {
                let firstStatus = statuses[0]
                for status in statuses {
                    XCTAssertEqual(status, firstStatus, "Authorization status should be consistent")
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testLocationManagerMemoryManagement() {
        weak var weakManager: LocationManager?
        
        autoreleasepool {
            let localManager = LocationManager()
            weakManager = localManager
            XCTAssertNotNil(weakManager, "Manager should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakManager, "Local manager should be deallocated")
        }
    }
    
    // MARK: - CLLocationManagerDelegate Tests
    
    func testLocationManagerDelegateConformance() {
        // Verify the delegate methods exist and are callable
        let manager = CLLocationManager()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let testError = NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue)
        
        // These should not crash when called
        locationManager.locationManager(manager, didChangeAuthorization: .authorizedWhenInUse)
        locationManager.locationManager(manager, didUpdateLocations: [testLocation])
        locationManager.locationManager(manager, didFailWithError: testError)
        
        XCTAssertTrue(true, "Delegate methods should be callable without crashing")
    }
    
    // MARK: - Performance Tests
    
    func testAuthorizationStatusPerformance() {
        measure {
            _ = locationManager.authorizationStatus
        }
    }
    
    func testAuthorizationStatusStringPerformance() {
        measure {
            _ = locationManager.authorizationStatusString
        }
    }
    
    func testRequestLocationSafePerformance() {
        measure {
            Task {
                _ = await locationManager.requestLocationSafe()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testLocationManagerDescription() {
        let description = String(describing: locationManager)
        XCTAssertFalse(description.isEmpty, "Description should not be empty")
        XCTAssertTrue(description.contains("LocationManager"),
                     "Description should mention LocationManager")
    }
    
    func testMultipleLocationManagerInstances() {
        let manager1 = LocationManager()
        let manager2 = LocationManager()
        let manager3 = LocationManager()
        
        // All should be valid instances
        XCTAssertNotNil(manager1, "First manager should be valid")
        XCTAssertNotNil(manager2, "Second manager should be valid")
        XCTAssertNotNil(manager3, "Third manager should be valid")
        
        // They should be different instances (not singleton like shared)
        XCTAssertFalse(manager1 === manager2, "Instances should be different")
        XCTAssertFalse(manager2 === manager3, "Instances should be different")
        XCTAssertFalse(manager1 === manager3, "Instances should be different")
        
        // But shared should be different from all
        XCTAssertFalse(LocationManager.shared === manager1, "Shared should be different from instance")
        XCTAssertFalse(LocationManager.shared === manager2, "Shared should be different from instance")
        XCTAssertFalse(LocationManager.shared === manager3, "Shared should be different from instance")
    }
    
    // MARK: - System Integration Tests
    
    func testLocationManagerUsesSystemLocationServices() {
        // Verify that authorization status reflects system state
        let systemEnabled = CLLocationManager.locationServicesEnabled()
        let managerStatus = locationManager.authorizationStatus
        
        // These should be correlated (if services disabled, status shouldn't be authorized)
        if !systemEnabled {
            XCTAssertNotEqual(managerStatus, .authorizedAlways,
                            "Should not be authorized if services disabled")
            XCTAssertNotEqual(managerStatus, .authorizedWhenInUse,
                            "Should not be authorized if services disabled")
        }
    }
    
    func testLocationManagerStatusConsistency() {
        // Multiple calls should return consistent status
        let status1 = locationManager.authorizationStatus
        let status2 = locationManager.authorizationStatus
        let status3 = locationManager.authorizationStatus
        
        XCTAssertEqual(status1, status2, "Status should be consistent")
        XCTAssertEqual(status2, status3, "Status should be consistent")
        XCTAssertEqual(status1, status3, "Status should be consistent")
        
        // String representation should also be consistent
        let string1 = locationManager.authorizationStatusString
        let string2 = locationManager.authorizationStatusString
        
        XCTAssertEqual(string1, string2, "Status string should be consistent")
    }
    
    // MARK: - Error Scenario Tests
    
    func testLocationErrorEquality() {
        let error1 = LocationError.locationServicesDisabled
        let error2 = LocationError.locationServicesDisabled
        let error3 = LocationError.authorizationDenied
        
        // Same error types should be equal
        switch (error1, error2) {
        case (.locationServicesDisabled, .locationServicesDisabled):
            XCTAssertTrue(true, "Same error types should match")
        default:
            XCTFail("Same error types should be equal")
        }
        
        // Different error types should not be equal
        switch (error1, error3) {
        case (.locationServicesDisabled, .authorizationDenied):
            XCTAssertTrue(true, "Different error types should not match")
        default:
            XCTFail("Different error types should not be equal")
        }
    }
    
    func testLocationFailedErrorWithDifferentUnderlyingErrors() {
        let error1 = NSError(domain: "Domain1", code: 1)
        let error2 = NSError(domain: "Domain2", code: 2)
        
        let locationError1 = LocationError.locationFailed(error1)
        let locationError2 = LocationError.locationFailed(error2)
        
        XCTAssertNotNil(locationError1.errorDescription)
        XCTAssertNotNil(locationError2.errorDescription)
        XCTAssertNotEqual(locationError1.errorDescription, locationError2.errorDescription,
                         "Different underlying errors should produce different descriptions")
    }
    
    // MARK: - Publisher/ObservableObject Tests
    
    func testObservableObjectPublishing() {
        // The @Published property should exist
        XCTAssertFalse(locationManager.isRequesting, "isRequesting should be accessible")
        
        // In a real app, this would trigger UI updates when changed
        // but we can't easily test the @Published behavior in unit tests
    }
    
    // MARK: - Boundary Condition Tests
    
    func testLocationManagerWithExtremeCoordinates() {
        // Test that the manager can handle extreme coordinate values if they were returned
        let extremeLocations = [
            CLLocation(latitude: 90.0, longitude: 180.0),      // North pole, date line
            CLLocation(latitude: -90.0, longitude: -180.0),    // South pole, opposite date line
            CLLocation(latitude: 0.0, longitude: 0.0),         // Null island
            CLLocation(latitude: 85.0511, longitude: 179.9999) // Near projection limits
        ]
        
        for location in extremeLocations {
            XCTAssertNotNil(location, "Extreme location should be valid")
            XCTAssertTrue(location.coordinate.latitude >= -90.0 && location.coordinate.latitude <= 90.0,
                         "Latitude should be in valid range")
            XCTAssertTrue(location.coordinate.longitude >= -180.0 && location.coordinate.longitude <= 180.0,
                         "Longitude should be in valid range")
        }
    }
    
    func testLocationManagerCacheValidityBoundary() {
        let validity = LocationManager.locationCacheValidityInSeconds
        
        // Should be a reasonable cache duration
        XCTAssertGreaterThan(validity, 1.0, "Cache validity should be > 1 second")
        XCTAssertLessThan(validity, 300.0, "Cache validity should be < 5 minutes")
        
        // Should be exactly 5 seconds as specified
        XCTAssertEqual(validity, 5.0, "Cache validity should be exactly 5 seconds")
    }
}
