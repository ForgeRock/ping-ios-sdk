//
//  LocationCollectorTests.swift
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

class LocationCollectorTests: XCTestCase {
    
    var collector: LocationCollector!
    var mockCLLocationManager: MockLocationManager!
    var mockLocationManager: LocationManager!
    
    override func setUp() {
        super.setUp()
        
        // Create mock CLLocationManager
        mockCLLocationManager = MockLocationManager()
        mockCLLocationManager.mockLocationServicesEnabled = true
        mockCLLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        MockLocationManager.shared = mockCLLocationManager
        
        // Create LocationManager with the mock
        mockLocationManager = LocationManager(
            locationManager: mockCLLocationManager,
            locationManagerType: MockLocationManager.self
        )
        
        // Create collector with mock LocationManager
        collector = LocationCollector(locationManager: mockLocationManager)
    }
    
    override func tearDown() {
        collector = nil
        mockLocationManager = nil
        mockCLLocationManager = nil
        MockLocationManager.shared = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "location", "LocationCollector should have correct key")
    }
    
    // MARK: - LocationInfo Tests
    
    func testLocationInfoInitializationWithValidCoordinates() {
        let latitude = 37.7749
        let longitude = -122.4194
        let locationInfo = LocationInfo(latitude: latitude, longitude: longitude)
        
        XCTAssertEqual(locationInfo.latitude, latitude, "Latitude should be stored correctly")
        XCTAssertEqual(locationInfo.longitude, longitude, "Longitude should be stored correctly")
    }
    
    func testLocationInfoInitializationWithNilCoordinates() {
        let locationInfo = LocationInfo(latitude: nil, longitude: nil)
        
        XCTAssertNil(locationInfo.latitude, "Latitude should be nil")
        XCTAssertNil(locationInfo.longitude, "Longitude should be nil")
    }
    
    func testLocationInfoInitializationWithMixedCoordinates() {
        let latitude = 37.7749
        let locationInfo = LocationInfo(latitude: latitude, longitude: nil)
        
        XCTAssertEqual(locationInfo.latitude, latitude, "Latitude should be stored correctly")
        XCTAssertNil(locationInfo.longitude, "Longitude should be nil")
    }
    
    func testLocationInfoCoordinateValidation() {
        // Test edge cases for coordinate values
        let testCases: [(lat: Double?, lng: Double?, valid: Bool)] = [
            (0.0, 0.0, true),
            (90.0, 180.0, true),
            (-90.0, -180.0, true),
            (37.7749, -122.4194, true),
            (nil, nil, true), // nil values are valid
            (-90.0, nil, true),
            (nil, 180.0, true)
        ]
        
        for testCase in testCases {
            let locationInfo = LocationInfo(latitude: testCase.lat, longitude: testCase.lng)
            
            if let lat = locationInfo.latitude {
                XCTAssertGreaterThanOrEqual(lat, -90.0, "Latitude should be >= -90")
                XCTAssertLessThanOrEqual(lat, 90.0, "Latitude should be <= 90")
            }
            
            if let lng = locationInfo.longitude {
                XCTAssertGreaterThanOrEqual(lng, -180.0, "Longitude should be >= -180")
                XCTAssertLessThanOrEqual(lng, 180.0, "Longitude should be <= 180")
            }
        }
    }
    
    func testLocationInfoCodable() throws {
        let latitude = 37.7749
        let longitude = -122.4194
        let locationInfo = LocationInfo(latitude: latitude, longitude: longitude)
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(locationInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded LocationInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(LocationInfo.self, from: data)
        
        XCTAssertEqual(locationInfo.latitude, decodedInfo.latitude, "Decoded latitude should match")
        XCTAssertEqual(locationInfo.longitude, decodedInfo.longitude, "Decoded longitude should match")
    }
    
    func testLocationInfoJSONStructure() throws {
        let latitude = 37.7749
        let longitude = -122.4194
        let locationInfo = LocationInfo(latitude: latitude, longitude: longitude)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(locationInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        XCTAssertEqual(jsonObject?["latitude"] as? Double, latitude, "JSON should contain correct latitude")
        XCTAssertEqual(jsonObject?["longitude"] as? Double, longitude, "JSON should contain correct longitude")
    }
    
    func testLocationInfoJSONWithNilValues() throws {
        let locationInfo = LocationInfo(latitude: nil, longitude: nil)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(locationInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        
        // Check that nil values are handled properly (might be NSNull or missing)
        if jsonObject?["latitude"] != nil {
            XCTAssertTrue(jsonObject?["latitude"] is NSNull, "Nil latitude should be NSNull in JSON")
        }
        if jsonObject?["longitude"] != nil {
            XCTAssertTrue(jsonObject?["longitude"] is NSNull, "Nil longitude should be NSNull in JSON")
        }
    }
    
    // MARK: - Collection Tests with Mock
    
    func testCollectorCollectSuccess() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "LocationCollector should return result on success")
        XCTAssertEqual(result?.latitude, 37.7749, "Latitude should match expected value")
        XCTAssertEqual(result?.longitude, -122.4194, "Longitude should match expected value")
        XCTAssertEqual(mockCLLocationManager.requestLocationCallCount, 1, "Should call requestLocation once")
    }
    
    func testCollectorCollectFailure() async {
        mockCLLocationManager.mockError = LocationError.authorizationDenied
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil on failure")
        XCTAssertEqual(mockCLLocationManager.requestLocationCallCount, 1, "Should still attempt requestLocation")
    }
    
    func testCollectorCollectWithNilLocation() async {
        mockCLLocationManager.mockLocation = nil
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when location manager returns nil")
    }
    
    func testCollectorCollectWithLocationServicesDisabled() async {
        mockCLLocationManager.mockLocationServicesEnabled = false
        mockCLLocationManager.mockError = LocationError.locationServicesDisabled
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when location services disabled")
    }
    
    func testCollectorCollectWithPermissionDenied() async {
        mockCLLocationManager.mockAuthorizationStatus = .denied
        mockCLLocationManager.mockError = LocationError.authorizationDenied
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when permission denied")
    }
    
    // MARK: - Multiple Collection Tests
    
    func testCollectorCollectMultipleTimes() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collection should succeed")
        XCTAssertNotNil(result2, "Second collection should succeed")
        
        XCTAssertEqual(result1?.latitude, result2?.latitude, "Results should be consistent")
        XCTAssertEqual(result1?.longitude, result2?.longitude, "Results should be consistent")
        
        // Due to caching, second request might not call the location manager
        XCTAssertGreaterThanOrEqual(mockCLLocationManager.requestLocationCallCount, 1,
                                   "Should call requestLocation at least once")
    }
    
    func testCollectorCollectWithCachedLocation() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        
        // First collection
        let result1 = await collector.collect()
        XCTAssertNotNil(result1, "First collection should succeed")
        
        // Second collection within cache validity period (< 5 seconds)
        let result2 = await collector.collect()
        XCTAssertNotNil(result2, "Should return cached location")
        XCTAssertEqual(result2?.latitude, 37.7749, "Should return cached latitude")
        XCTAssertEqual(result2?.longitude, -122.4194, "Should return cached longitude")
        
        // Should only call requestLocation once due to caching
        XCTAssertEqual(mockCLLocationManager.requestLocationCallCount, 1,
                      "Should use cache for second request")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        mockCLLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testLocationCollectorNotInDefaultSet() {
        // LocationCollector is not included in default set due to privacy concerns
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let locationCollector = defaultCollectors.first { $0.key == "location" }
        
        XCTAssertNil(locationCollector, "Default collectors should not include LocationCollector")
    }
    
    func testLocationCollectorInArrayCollection() async throws {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["location"], "Result should contain location data")
        
        // Verify the structure matches expectations
        if let locationData = result["location"] as? [String: Any] {
            XCTAssertEqual(locationData["latitude"] as? Double, 37.7749, "Should have correct latitude")
            XCTAssertEqual(locationData["longitude"] as? Double, -122.4194, "Should have correct longitude")
        } else {
            XCTFail("Location data should be a dictionary")
        }
    }
    
    func testLocationCollectorInArrayCollectionWithFailure() async throws {
        mockCLLocationManager.mockError = LocationError.authorizationDenied
        
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        // Should not include location data when collection fails
        XCTAssertEqual(result.count, 0, "Should have no results when location collection fails")
        XCTAssertNil(result["location"], "Should not contain location data on failure")
    }
    
    func testCollectorHandlesAllErrorTypes() async {
        let errorTypes: [LocationError] = [
            .locationServicesDisabled,
            .authorizationDenied,
            .authorizationRestricted,
            .missingPrivacyConsent,
            .locationFailed(NSError(domain: "test", code: 1))
        ]
        
        for error in errorTypes {
            mockCLLocationManager.mockError = error
            mockCLLocationManager.requestLocationCallCount = 0
            
            let result = await collector.collect()
            XCTAssertNil(result, "Should return nil for error: \(error)")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testSequentialCollection() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        
        // Sequential requests (realistic usage)
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        let result3 = await collector.collect()
        
        XCTAssertNotNil(result1, "First request should succeed")
        XCTAssertNotNil(result2, "Second request should succeed (cached)")
        XCTAssertNotNil(result3, "Third request should succeed (cached)")
        
        // All should have same coordinates
        XCTAssertEqual(result1?.latitude, result2?.latitude, "Results should be consistent")
        XCTAssertEqual(result2?.latitude, result3?.latitude, "Results should be consistent")
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: LocationCollector?
        
        autoreleasepool {
            let mock = MockLocationManager()
            let manager = LocationManager(locationManager: mock, locationManagerType: MockLocationManager.self)
            let localCollector = LocationCollector(locationManager: manager)
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Collector should be deallocated when out of scope
        XCTAssertNil(weakCollector, "Collector should be deallocated")
    }
    
    // MARK: - Edge Case Tests
    
    func testLocationInfoWithExtremeCoordinates() {
        // Test edge coordinate values
        let extremeCases = [
            (lat: 90.0, lng: 180.0),     // North pole, International Date Line
            (lat: -90.0, lng: -180.0),   // South pole, opposite side
            (lat: 0.0, lng: 0.0),        // Null Island
            (lat: 85.0511, lng: 0.0),    // Near North Pole (Web Mercator limit)
            (lat: -85.0511, lng: 0.0)    // Near South Pole (Web Mercator limit)
        ]
        
        for (lat, lng) in extremeCases {
            let locationInfo = LocationInfo(latitude: lat, longitude: lng)
            XCTAssertEqual(locationInfo.latitude, lat, "Extreme latitude should be preserved")
            XCTAssertEqual(locationInfo.longitude, lng, "Extreme longitude should be preserved")
        }
    }
    
    func testLocationInfoPrecision() {
        // Test high precision coordinates
        let highPrecisionLat = 37.77493
        let highPrecisionLng = -122.41941
        
        let locationInfo = LocationInfo(latitude: highPrecisionLat, longitude: highPrecisionLng)
        
        XCTAssertEqual(locationInfo.latitude, highPrecisionLat,
                      "High precision latitude should be preserved")
        XCTAssertEqual(locationInfo.longitude, highPrecisionLng,
                      "High precision longitude should be preserved")
    }
    
    func testCollectorWithLocationManagerReplacement() async {
        // Create a second mock manager with different location
        let newMock = MockLocationManager()
        newMock.mockAuthorizationStatus = .authorizedWhenInUse
        newMock.mockLocationServicesEnabled = true
        newMock.mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        MockLocationManager.shared = newMock
        
        let newManager = LocationManager(
            locationManager: newMock,
            locationManagerType: MockLocationManager.self
        )
        
        collector.locationManager = newManager
        
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "Should work with replaced location manager")
        XCTAssertEqual(result?.latitude, 40.7128, "Should use new manager's location")
        XCTAssertEqual(result?.longitude, -74.0060, "Should use new manager's location")
        
        // Restore original mock
        MockLocationManager.shared = mockCLLocationManager
        collector.locationManager = mockLocationManager
    }
    
    func testCollectorInitializationWithDefaultManager() {
        // Test that collector can be initialized without explicit dependency injection
        let defaultCollector = LocationCollector()
        
        XCTAssertNotNil(defaultCollector, "Should initialize with default manager")
        XCTAssertNotNil(defaultCollector.locationManager, "Should have location manager")
        XCTAssertEqual(defaultCollector.key, "location", "Should have correct key")
    }
}
