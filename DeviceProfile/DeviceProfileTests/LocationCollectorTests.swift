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
    var mockLocationManager: MockLocationManagerForTests!
    
    override func setUp() {
        super.setUp()
        collector = LocationCollector()
        mockLocationManager = MockLocationManagerForTests()
        collector.locationManager = mockLocationManager
    }
    
    override func tearDown() {
        collector = nil
        mockLocationManager = nil
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
        mockLocationManager.mockLocation = expectedLocation
        
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "LocationCollector should return result on success")
        XCTAssertEqual(result?.latitude, 37.7749, "Latitude should match expected value")
        XCTAssertEqual(result?.longitude, -122.4194, "Longitude should match expected value")
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1, "Should call requestLocation once")
    }
    
    func testCollectorCollectFailure() async {
        mockLocationManager.mockError = LocationError.authorizationDenied
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil on failure")
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 1, "Should still attempt requestLocation")
    }
    
    func testCollectorCollectWithNilLocation() async {
        mockLocationManager.mockLocation = nil
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when location manager returns nil")
    }
    
    func testCollectorCollectWithLocationServicesDisabled() async {
        mockLocationManager.mockError = LocationError.locationServicesDisabled
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when location services disabled")
    }
    
    func testCollectorCollectWithPermissionDenied() async {
        mockLocationManager.mockError = LocationError.authorizationDenied
        
        let result = await collector.collect()
        
        XCTAssertNil(result, "LocationCollector should return nil when permission denied")
    }
    
    // MARK: - Multiple Collection Tests
    
    func testCollectorCollectMultipleTimes() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager.mockLocation = expectedLocation
        
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collection should succeed")
        XCTAssertNotNil(result2, "Second collection should succeed")
        
        XCTAssertEqual(result1?.latitude, result2?.latitude, "Results should be consistent")
        XCTAssertEqual(result1?.longitude, result2?.longitude, "Results should be consistent")
        XCTAssertEqual(mockLocationManager.requestLocationCallCount, 2, "Should call requestLocation twice")
    }
    
    func testCollectorCollectWithCachedLocation() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager.mockLocation = expectedLocation
        mockLocationManager.shouldReturnCachedLocation = true
        
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "Should return cached location")
        XCTAssertEqual(result?.latitude, 37.7749, "Should return cached latitude")
        XCTAssertEqual(result?.longitude, -122.4194, "Should return cached longitude")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
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
        mockLocationManager.mockLocation = expectedLocation
        
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
        mockLocationManager.mockError = LocationError.authorizationDenied
        
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
            mockLocationManager.reset()
            mockLocationManager.mockError = error
            
            let result = await collector.collect()
            XCTAssertNil(result, "Should return nil for error: \(error)")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager.mockLocation = expectedLocation
        
        let iterations = 5
        
        await withTaskGroup(of: LocationInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.collector.collect()
                }
            }
            
            var results: [LocationInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All successful results should be identical
            let validResults = results.compactMap { $0 }
            if validResults.count > 1 {
                let first = validResults[0]
                for result in validResults {
                    XCTAssertEqual(result.latitude, first.latitude, "Concurrent results should be consistent")
                    XCTAssertEqual(result.longitude, first.longitude, "Concurrent results should be consistent")
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: LocationCollector?
        
        autoreleasepool {
            let localCollector = LocationCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
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
        
        XCTAssertEqual(locationInfo.latitude!, highPrecisionLat, accuracy: 0.000001,
                      "High precision latitude should be preserved")
        XCTAssertEqual(locationInfo.longitude!, highPrecisionLng, accuracy: 0.000001,
                      "High precision longitude should be preserved")
    }
    
    func testCollectorWithLocationManagerReplacement() async {
        // Test that collector works with different location manager instances
        let originalManager = collector.locationManager
        let newMockManager = MockLocationManagerForTests()
        newMockManager.mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        
        collector.locationManager = newMockManager
        
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "Should work with replaced location manager")
        XCTAssertEqual(result?.latitude, 40.7128, "Should use new manager's location")
        XCTAssertEqual(result?.longitude, -74.0060, "Should use new manager's location")
        
        // Restore original manager
        collector.locationManager = originalManager
    }
}

// MARK: - Mock LocationManager for Testing

class MockLocationManagerForTests: LocationManager {
    var mockLocation: CLLocation?
    var mockError: Error?
    var shouldReturnCachedLocation = false
    var authorizationStatusOverride: CLAuthorizationStatus?
    var requestLocationCallCount = 0
    
    override var authorizationStatus: CLAuthorizationStatus {
        return authorizationStatusOverride ?? .authorizedWhenInUse
    }
    
    override func requestLocation() async throws -> CLLocation? {
        requestLocationCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if shouldReturnCachedLocation, let cached = mockLocation {
            return cached
        }
        
        return mockLocation
    }
    
    override func requestLocationSafe() async -> CLLocation? {
        do {
            return try await requestLocation()
        } catch {
            return nil
        }
    }
    
    func reset() {
        mockLocation = nil
        mockError = nil
        shouldReturnCachedLocation = false
        authorizationStatusOverride = nil
        requestLocationCallCount = 0
    }
}
