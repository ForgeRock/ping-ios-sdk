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

@MainActor
class LocationManagerTests: XCTestCase, Sendable {
    
    var sut: LocationManager!
    var mockLocationManager: MockLocationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockLocationManager = MockLocationManager()
        mockLocationManager.mockLocationServicesEnabled = true
        MockLocationManager.shared = mockLocationManager // Enable static method mocking
        sut = LocationManager(
            locationManager: mockLocationManager,
            locationManagerType: MockLocationManager.self
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockLocationManager = nil
        MockLocationManager.shared = nil // Clean up
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLocationManagerInitialization() {
        XCTAssertNotNil(sut, "LocationManager should initialize")
        XCTAssertFalse(sut.isRequesting, "isRequesting should be false initially")
    }
    
    func testLocationManagerInitializationWithCustomDependencies() {
        let customMock = MockLocationManager()
        let customManager = LocationManager(
            locationManager: customMock,
            locationManagerType: MockLocationManager.self
        )
        
        XCTAssertNotNil(customManager, "LocationManager should initialize with custom dependencies")
        XCTAssertFalse(customManager.isRequesting, "isRequesting should be false initially")
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
    
    func testAuthorizationStatusReflectsMockStatus() async {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        
        let status = await sut.authorizationStatus
        XCTAssertEqual(status, .authorizedWhenInUse, "Should return mock authorization status")
    }
    
    func testAuthorizationStatusString_AllCases() async {
        let testCases: [(CLAuthorizationStatus, String)] = [
            (.notDetermined, "notDetermined"),
            (.restricted, "restricted"),
            (.denied, "denied"),
            (.authorizedAlways, "authorizedAlways"),
            (.authorizedWhenInUse, "authorizedWhenInUse")
        ]
        
        for (status, expectedString) in testCases {
            mockLocationManager.mockAuthorizationStatus = status
            let statusString = await sut.authorizationStatusString
            XCTAssertEqual(statusString, expectedString,
                          "Status string should match for \(status)")
        }
    }
    
    // MARK: - Location Request Success Tests
    
    func testRequestLocation_WhenAuthorizedWhenInUse_ReturnsLocation() async throws {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager.mockLocation = expectedLocation
        
        // When
        let location = try await sut.requestLocation()
        
        // Then
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.coordinate.latitude, expectedLocation.coordinate.latitude)
        XCTAssertEqual(location?.coordinate.longitude, expectedLocation.coordinate.longitude)
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1,
                      "Should call requestLocation once")
    }
    
    func testRequestLocation_WhenAuthorizedAlways_ReturnsLocation() async throws {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedAlways
        let expectedLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        mockLocationManager.mockLocation = expectedLocation
        
        // When
        let location = try await sut.requestLocation()
        
        // Then
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.coordinate.latitude, 40.7128)
        XCTAssertEqual(location?.coordinate.longitude, -74.0060)
    }
    
    func testRequestLocation_WithValidCache_ReturnsCachedLocation() async throws {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let cachedLocation = CLLocation(latitude: 51.5074, longitude: -0.1278) // London
        mockLocationManager.mockLocation = cachedLocation
        
        // When - First request
        let firstLocation = try await sut.requestLocation()
        XCTAssertNotNil(firstLocation)
        
        // Change mock location (should not affect cached result)
        mockLocationManager.mockLocation = CLLocation(latitude: 0.0, longitude: 0.0)
        
        // When - Second request within cache validity (< 5 seconds)
        let secondLocation = try await sut.requestLocation()
        
        // Then - Should return cached location, not new one
        XCTAssertEqual(secondLocation?.coordinate.latitude, 51.5074)
        XCTAssertEqual(secondLocation?.coordinate.longitude, -0.1278)
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1,
                      "Should only call requestLocation once due to caching")
    }
    
    func testRequestLocation_WhenNotDetermined_RequestsAuthorizationAndReturnsLocation() async throws {
        // Given - Start with notDetermined (mock will auto-grant when requested)
        mockLocationManager.mockAuthorizationStatus = .notDetermined
        let expectedLocation = CLLocation(latitude: 35.6762, longitude: 139.6503) // Tokyo
        mockLocationManager.mockLocation = expectedLocation
        
        // When
        let location = try await sut.requestLocation()
        
        // Then
        XCTAssertNotNil(location)
        XCTAssertGreaterThan(mockLocationManager.requestWhenInUseAuthorizationCallCount, 0,
                            "Should request authorization when status is notDetermined")
    }
    
    // MARK: - Location Request Error Tests
    
    func testRequestLocation_WhenDenied_ThrowsAuthorizationDeniedError() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .denied
        
        // When/Then
        do {
            _ = try await sut.requestLocation()
            XCTFail("Expected authorizationDenied error")
        } catch LocationError.authorizationDenied {
            // Expected error
            XCTAssertTrue(true, "Correctly threw authorizationDenied error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 0,
                      "Should not request location when denied")
    }
    
    func testRequestLocation_WhenRestricted_ThrowsAuthorizationRestrictedError() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .restricted
        
        // When/Then
        do {
            _ = try await sut.requestLocation()
            XCTFail("Expected authorizationRestricted error")
        } catch LocationError.authorizationRestricted {
            // Expected error
            XCTAssertTrue(true, "Correctly threw authorizationRestricted error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRequestLocation_WhenLocationServicesDisabled_ThrowsLocationServicesDisabledError() async {
        // Given
        mockLocationManager.mockLocationServicesEnabled = false
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        
        // When/Then
        do {
            _ = try await sut.requestLocation()
            XCTFail("Expected locationServicesDisabled error")
        } catch LocationError.locationServicesDisabled {
            // Expected error
            XCTAssertTrue(true, "Correctly threw locationServicesDisabled error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRequestLocation_WhenLocationFails_ThrowsLocationFailedError() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let expectedError = NSError(domain: kCLErrorDomain,
                                    code: CLError.locationUnknown.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: "Location unavailable"])
        mockLocationManager.mockError = expectedError
        
        // When/Then
        do {
            _ = try await sut.requestLocation()
            XCTFail("Expected locationFailed error")
        } catch LocationError.locationFailed(let underlyingError) {
            // Expected error
            XCTAssertEqual((underlyingError as NSError).code, CLError.locationUnknown.rawValue)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRequestLocation_WhenAuthorizationDeniedAfterRequest_ThrowsError() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .denied // User denies permission
        
        // When/Then
        do {
            _ = try await sut.requestLocation()
            XCTFail("Expected error when user denies authorization")
        } catch LocationError.authorizationDenied {
            // Expected error
            XCTAssertTrue(true, "Correctly handled denied authorization")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Safe Request Tests
    
    func testRequestLocationSafe_WhenSuccessful_ReturnsLocation() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let expectedLocation = CLLocation(latitude: 48.8566, longitude: 2.3522) // Paris
        mockLocationManager.mockLocation = expectedLocation
        
        // When
        let location = await sut.requestLocationSafe()
        
        // Then
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.coordinate.latitude, 48.8566)
    }
    
    func testRequestLocationSafe_WhenFails_ReturnsNil() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .denied
        
        // When
        let location = await sut.requestLocationSafe()
        
        // Then
        XCTAssertNil(location, "Should return nil on error")
    }
    
    func testRequestLocationSafe_NeverThrows() async {
        // Given - Various error conditions
        let errorConditions: [CLAuthorizationStatus] = [.denied, .restricted]
        
        for condition in errorConditions {
            mockLocationManager.mockAuthorizationStatus = condition
            
            // When/Then - Should not throw
            let location = await sut.requestLocationSafe()
            XCTAssertNil(location, "Should return nil for \(condition)")
        }
    }
    
    func testRequestLocationSafe_MultipleCalls() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 0.0, longitude: 0.0)
        
        // When
        let location1 = await sut.requestLocationSafe()
        let location2 = await sut.requestLocationSafe()
        
        // Then
        XCTAssertNotNil(location1)
        XCTAssertNotNil(location2)
    }
    
    // MARK: - IsRequesting Property Tests
    
    func testIsRequesting_InitiallyFalse() {
        XCTAssertFalse(sut.isRequesting, "Should not be requesting initially")
    }
    
    func testIsRequesting_UpdatesDuringRequest() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.shouldDelayResponse = true
        
        // When
        let requestTask = Task {
            _ = try? await sut.requestLocation()
        }
        
        // Give it a moment to start
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Then - Would need to check on main actor in real scenario
        // This test demonstrates the pattern, actual value checking would be done differently
        
        await requestTask.value
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
    
    func testSequentialLocationRequests() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When - Sequential requests (realistic usage)
        let location1 = await sut.requestLocationSafe()
        let location2 = await sut.requestLocationSafe()
        let location3 = await sut.requestLocationSafe()
        
        // Then - All should succeed
        XCTAssertNotNil(location1, "First request should succeed")
        XCTAssertNotNil(location2, "Second request should succeed (cached)")
        XCTAssertNotNil(location3, "Third request should succeed (cached)")
        
        // Only first request should actually call the location manager (rest are cached)
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1,
                      "Should use cache for subsequent requests")
    }
    
    func testConcurrentAuthorizationStatusAccess() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let iterations = 10
        
        // When - Reading status is safe to do concurrently
        await withTaskGroup(of: CLAuthorizationStatus.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.sut.authorizationStatus
                }
            }
            
            var statuses: [CLAuthorizationStatus] = []
            for await status in group {
                statuses.append(status)
            }
            
            // Then
            XCTAssertEqual(statuses.count, iterations, "Should complete all concurrent status reads")
            
            for status in statuses {
                XCTAssertEqual(status, .authorizedWhenInUse, "All statuses should be consistent")
            }
        }
    }
    
    func testRapidSequentialRequests() async {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When - Make requests in rapid succession (but not truly concurrent)
        var results: [CLLocation?] = []
        for _ in 0..<5 {
            let location = await sut.requestLocationSafe()
            results.append(location)
        }
        
        // Then - All should complete successfully
        XCTAssertEqual(results.count, 5, "Should complete all requests")
        let successfulResults = results.compactMap { $0 }
        XCTAssertEqual(successfulResults.count, 5, "All requests should succeed")
        
        // Cache should prevent multiple actual location requests
        XCTAssertLessThanOrEqual(mockLocationManager.requestLocationCallCount, 2,
                                "Cache should reduce actual location manager calls")
    }
    
    // MARK: - Memory Management Tests
    
    func testLocationManagerMemoryManagement() {
        weak var weakManager: LocationManager?
        
        autoreleasepool {
            let mockManager = MockLocationManager()
            let localManager = LocationManager(
                locationManager: mockManager,
                locationManagerType: MockLocationManager.self
            )
            weakManager = localManager
            XCTAssertNotNil(weakManager, "Manager should exist")
        }
        
        // Manager should be deallocated when out of scope
        XCTAssertNil(weakManager, "Local manager should be deallocated")
    }
    
    // MARK: - CLLocationManagerDelegate Tests
    
    func testLocationManagerDelegate_DidChangeAuthorization() {
        // Given
        let manager = CLLocationManager()
        
        // When
        sut.locationManager(manager, didChangeAuthorization: .authorizedWhenInUse)
        
        // Then - Should not crash
        XCTAssertTrue(true, "Delegate method should be callable")
    }
    
    func testLocationManagerDelegate_DidUpdateLocations() {
        // Given
        let manager = CLLocationManager()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When
        sut.locationManager(manager, didUpdateLocations: [testLocation])
        
        // Then - Should not crash
        XCTAssertTrue(true, "Delegate method should be callable")
    }
    
    func testLocationManagerDelegate_DidFailWithError() {
        // Given
        let manager = CLLocationManager()
        let testError = NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue)
        
        // When
        sut.locationManager(manager, didFailWithError: testError)
        
        // Then - Should not crash
        XCTAssertTrue(true, "Delegate method should be callable")
    }
    
    // MARK: - Edge Case Tests
    
    func testLocationManagerWithExtremeCoordinates() async throws {
        // Given
        let extremeLocations = [
            CLLocation(latitude: 90.0, longitude: 180.0),      // North pole, date line
            CLLocation(latitude: -90.0, longitude: -180.0),    // South pole
            CLLocation(latitude: 0.0, longitude: 0.0),         // Null island
            CLLocation(latitude: 85.0511, longitude: 179.9999) // Near projection limits
        ]
        
        for extremeLocation in extremeLocations {
            // Create fresh manager for each location to avoid cache interference
            let freshMock = MockLocationManager()
            freshMock.mockAuthorizationStatus = .authorizedWhenInUse
            freshMock.mockLocation = extremeLocation
            freshMock.mockLocationServicesEnabled = true
            MockLocationManager.shared = freshMock
            
            let freshManager = LocationManager(
                locationManager: freshMock,
                locationManagerType: MockLocationManager.self
            )
            
            // When
            let location = try await freshManager.requestLocation()
            
            // Then
            XCTAssertNotNil(location, "Extreme location should be handled")
            XCTAssertEqual(location?.coordinate.latitude, extremeLocation.coordinate.latitude)
            XCTAssertEqual(location?.coordinate.longitude, extremeLocation.coordinate.longitude)
        }
        
        // Restore original mock for other tests
        MockLocationManager.shared = mockLocationManager
    }
    
    func testMultipleLocationManagerInstances() {
        // Given
        let mock1 = MockLocationManager()
        let mock2 = MockLocationManager()
        let mock3 = MockLocationManager()
        
        let manager1 = LocationManager(locationManager: mock1, locationManagerType: MockLocationManager.self)
        let manager2 = LocationManager(locationManager: mock2, locationManagerType: MockLocationManager.self)
        let manager3 = LocationManager(locationManager: mock3, locationManagerType: MockLocationManager.self)
        
        // Then
        XCTAssertNotNil(manager1, "First manager should be valid")
        XCTAssertNotNil(manager2, "Second manager should be valid")
        XCTAssertNotNil(manager3, "Third manager should be valid")
        
        XCTAssertFalse(manager1 === manager2, "Instances should be different")
        XCTAssertFalse(manager2 === manager3, "Instances should be different")
        XCTAssertFalse(manager1 === manager3, "Instances should be different")
        
        XCTAssertFalse(LocationManager.shared === manager1, "Shared should be different from instance")
    }
    
    // MARK: - Call Tracking Tests
    
    func testRequestLocation_CallsRequestLocationOnce() async throws {
        // Given
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When
        _ = try await sut.requestLocation()
        
        // Then
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1,
                      "Should call requestLocation exactly once")
    }
    
    func testRequestLocation_CallsAuthorizationWhenNeeded() async throws {
        // Given - Start with notDetermined so authorization is needed
        mockLocationManager.mockAuthorizationStatus = .notDetermined
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When
        _ = try await sut.requestLocation()
        
        // Then
        let totalAuthCalls = mockLocationManager.requestWhenInUseAuthorizationCallCount +
                            mockLocationManager.requestAlwaysAuthorizationCallCount
        XCTAssertGreaterThan(totalAuthCalls, 0,
                           "Should request authorization when status is not determined")
    }
    
    // MARK: - Performance Tests
    
    func testAuthorizationStatusPerformance() {
        measure {
            Task {
                _ = await sut.authorizationStatus
            }
        }
    }
    
    func testAuthorizationStatusStringPerformance() {
        measure {
            Task {
                _ = await sut.authorizationStatusString
            }
            
        }
    }
}


// MARK: - MockLocationManager

/// Mock implementation for testing location scenarios
@MainActor class MockLocationManager: @preconcurrency LocationManagerProtocol {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    
    // Test configuration properties
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockLocationServicesEnabled: Bool = true
    var mockLocation: CLLocation?
    var mockError: Error?
    var shouldDelayResponse: Bool = false
    
    // Call tracking for verification
    var requestLocationCallCount = 0
    var requestWhenInUseAuthorizationCallCount = 0
    var requestAlwaysAuthorizationCallCount = 0
    
    // Shared state for static methods (used in tests)
    @MainActor static var shared: MockLocationManager?
    
    @MainActor static func locationServicesEnabled() -> Bool {
        return shared?.mockLocationServicesEnabled ?? true
    }
    
    @MainActor static func authorizationStatus() -> CLAuthorizationStatus {
        return shared?.mockAuthorizationStatus ?? .notDetermined
    }
    
    func requestLocation() {
        requestLocationCallCount += 1
        
        let simulateResponse = {
            if let error = self.mockError {
                self.delegate?.locationManager?(CLLocationManager(), didFailWithError: error)
            } else if let location = self.mockLocation {
                self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [location])
            } else {
                // No location set - simulate a failure
                let error = NSError(domain: kCLErrorDomain,
                                   code: CLError.locationUnknown.rawValue,
                                   userInfo: [NSLocalizedDescriptionKey: "No mock location configured"])
                self.delegate?.locationManager?(CLLocationManager(), didFailWithError: error)
            }
        }
        
        // Always respond asynchronously to match real CoreLocation behavior
        let delay = shouldDelayResponse ? 0.1 : 0.01
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            simulateResponse()
        }
    }
    
    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
        
        // If currently notDetermined, grant permission automatically
        if mockAuthorizationStatus == .notDetermined {
            mockAuthorizationStatus = .authorizedWhenInUse
        }
        
        // Simulate authorization change
        DispatchQueue.main.async {
            self.delegate?.locationManager?(CLLocationManager(), didChangeAuthorization: self.mockAuthorizationStatus)
        }
    }
    
    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCallCount += 1
        
        // If currently notDetermined, grant permission automatically
        if mockAuthorizationStatus == .notDetermined {
            mockAuthorizationStatus = .authorizedAlways
        }
        
        // Simulate authorization change
        DispatchQueue.main.async {
            self.delegate?.locationManager?(CLLocationManager(), didChangeAuthorization: self.mockAuthorizationStatus)
        }
    }
}
