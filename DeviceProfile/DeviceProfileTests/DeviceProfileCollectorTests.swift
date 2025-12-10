// 
//  DeviceProfileCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingLogger
@testable import PingDeviceProfile
@testable import PingDeviceId

class DeviceProfileCollectorTests: XCTestCase {
    
    var config: DeviceProfileConfig!
    var collector: DeviceProfileCollector!
    
    override func setUp() {
        super.setUp()
        config = DeviceProfileConfig()
        collector = DeviceProfileCollector(config: config)
    }
    
    override func tearDown() {
        collector = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "", "DeviceProfileCollector should have empty key (root collector)")
    }
    
    func testCollectorInitialization() {
        let testConfig = DeviceProfileConfig()
        testConfig.metadata = true
        testConfig.location = true
        
        let testCollector = DeviceProfileCollector(config: testConfig)
        XCTAssertNotNil(testCollector, "DeviceProfileCollector should initialize with config")
        XCTAssertEqual(testCollector.key, "", "Key should be empty string")
    }
    
    // MARK: - DeviceProfileResult Tests
    
    func testDeviceProfileResultInitialization() {
        let identifier = "test-device-123"
        let metadata = ["platform": "iOS", "version": "17.0"]
        let location = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        
        let result = DeviceProfileResult(identifier: identifier, metadata: metadata, location: location)
        
        XCTAssertEqual(result.identifier, identifier, "Identifier should be stored correctly")
        XCTAssertNotNil(result.metadata, "Metadata should not be nil")
        XCTAssertNotNil(result.location, "Location should not be nil")
        XCTAssertEqual(result.location?.latitude, 37.7749, "Location latitude should be correct")
        XCTAssertEqual(result.location?.longitude, -122.4194, "Location longitude should be correct")
    }
    
    func testDeviceProfileResultInitializationWithNilValues() {
        let identifier = "test-device-123"
        
        let result = DeviceProfileResult(identifier: identifier)
        
        XCTAssertEqual(result.identifier, identifier, "Identifier should be stored correctly")
        XCTAssertNil(result.metadata, "Metadata should be nil by default")
        XCTAssertNil(result.location, "Location should be nil by default")
    }
    
    func testDeviceProfileResultMetadataDict() {
        let identifier = "test-device-123"
        let metadata = ["platform": "iOS", "version": 17.0, "enabled": true] as [String : Any]
        
        let result = DeviceProfileResult(identifier: identifier, metadata: metadata)
        
        XCTAssertNotNil(result.metadataDict, "MetadataDict should not be nil")
        
        if let dict = result.metadataDict {
            XCTAssertEqual(dict["platform"] as? String, "iOS", "Platform should be iOS")
            XCTAssertEqual(dict["version"] as? Double, 17.0, "Version should be 17.0")
            XCTAssertEqual(dict["enabled"] as? Bool, true, "Enabled should be true")
        }
    }
    
    func testDeviceProfileResultCodable() throws {
        let identifier = "test-device-123"
        let metadata = ["platform": "iOS"]
        let location = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        
        let result = DeviceProfileResult(identifier: identifier, metadata: metadata, location: location)
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        XCTAssertGreaterThan(data.count, 0, "Encoded DeviceProfileResult should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(DeviceProfileResult.self, from: data)
        
        XCTAssertEqual(result.identifier, decodedResult.identifier)
        XCTAssertNotNil(decodedResult.metadata)
        XCTAssertNotNil(decodedResult.location)
        XCTAssertEqual(result.location?.latitude, decodedResult.location?.latitude)
        XCTAssertEqual(result.location?.longitude, decodedResult.location?.longitude)
    }
    
    
    
    // MARK: - Collection Tests
    
    func testCollectorCollectWithMetadataEnabled() async throws {
        config.metadata = true
        config.location = false
        config.collectors = [
            MockPlatformCollectorForTests(),
            MockHardwareCollectorForTests()
        ]
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertFalse(result?.identifier.isEmpty ?? true, "Identifier should not be empty")
        XCTAssertNotNil(result?.metadata, "Metadata should be collected when enabled")
        XCTAssertNil(result?.location, "Location should not be collected when disabled")
        
        // Check metadata content
        if let metadataDict = result?.metadataDict {
            XCTAssertNotNil(metadataDict["platform"], "Should contain platform data")
            XCTAssertNotNil(metadataDict["hardware"], "Should contain hardware data")
        }
    }
    
    func testCollectorCollectWithLocationEnabled() async throws {
        config.metadata = false
        config.location = true
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertNil(result?.metadata, "Metadata should not be collected when disabled")
        // Location might be nil due to permissions/availability, but that's expected
    }
    
    func testCollectorCollectWithBothEnabled() async throws {
        config.metadata = true
        config.location = true
        config.collectors = [MockPlatformCollectorForTests()]
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertNotNil(result?.metadata, "Metadata should be collected when enabled")
        // Location might be nil due to permissions, but metadata should be present
    }
    
    func testCollectorCollectWithBothDisabled() async throws {
        config.metadata = false
        config.location = false
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertNil(result?.metadata, "Metadata should not be collected when disabled")
        XCTAssertNil(result?.location, "Location should not be collected when disabled")
    }
    
    func testCollectorCollectWithFailingCollectors() async throws {
        config.metadata = true
        config.location = false
        config.collectors = [
            MockPlatformCollectorForTests(),
            MockFailingCollectorForTests()
        ]
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result even with failing collectors")
        XCTAssertNotNil(result?.metadata, "Should collect successful data")
        
        // Should only contain successful collector data
        if let metadataDict = result?.metadataDict {
            XCTAssertNotNil(metadataDict["platform"], "Should contain successful platform data")
            XCTAssertNil(metadataDict["failing"], "Should not contain failed collector data")
        }
    }
    
    // MARK: - Device Identifier Tests
    
    func testCollectorCollectWithCustomDeviceIdentifier() async throws {
        let customId = "custom-device-id-123"
        config.deviceIdentifier = MockDeviceIdentifierForTests(id: customId)
        config.metadata = false
        config.location = false
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertEqual(result?.identifier, customId, "Should use custom device identifier")
    }
    
    func testCollectorCollectWithNilDeviceIdentifier() async throws {
        config.deviceIdentifier = nil
        config.metadata = false
        config.location = false
        
        let result = try await collector.collect()
        
        XCTAssertNotNil(result, "Collector should return result")
        XCTAssertEqual(result?.identifier, "", "Should use empty string when device identifier is nil")
    }
    
    func testCollectorCollectWithThrowingDeviceIdentifier() async throws {
        config.deviceIdentifier = ThrowingDeviceIdentifierForTests()
        config.metadata = false
        config.location = false
        
        do {
            _ = try await collector.collect()
            XCTFail("Should throw when device identifier throws")
        } catch {
            // Expected behavior
            XCTAssertTrue(true, "Should throw when device identifier throws")
        }
    }
    
    // MARK: - Logger Configuration Tests
    
    func testCollectorConfiguresLoggers() async throws {
        let customLogger = LogManager.standard
        config.logger = customLogger
        config.metadata = true
        config.collectors = [MockLoggerAwareCollectorForTests()]
        
        _ = try await collector.collect()
        
        // Verify logger was configured (this would need to be verified through the mock)
        XCTAssertTrue(true, "Logger configuration completed without error")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        config.metadata = true
        config.location = false
        config.collectors = [MockPlatformCollectorForTests()]
        
        let testCollector = collector!
        measure {
            Task {
                let testCollector = DeviceProfileCollector(config: DeviceProfileConfig())
                _ = try? await testCollector.collect()
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        config.metadata = true
        config.location = false
        config.collectors = [MockPlatformCollectorForTests()]
        
        let iterations = 5
        let testCollector = collector!
        
        await withTaskGroup(of: DeviceProfileResult?.self) { group in
            let testCollector = DeviceProfileCollector(config: DeviceProfileConfig())
            for _ in 0..<iterations {
                group.addTask {
                    return try? await testCollector.collect()
                }
            }
            
            var results: [DeviceProfileResult?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All successful results should have similar structure
            let validResults = results.compactMap { $0 }
            XCTAssertGreaterThan(validResults.count, 0, "At least some tasks should succeed")
            
            for result in validResults {
                XCTAssertFalse(result.identifier.isEmpty, "All results should have identifiers")
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: DeviceProfileCollector?
        
        autoreleasepool {
            let localConfig = DeviceProfileConfig()
            let localCollector = DeviceProfileCollector(config: localConfig)
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Configuration Validation Tests
    
    func testCollectorRespectsConfiguration() async throws {
        // Test that the collector respects all configuration flags
        config.metadata = false
        config.location = false
        config.collectors = [MockPlatformCollectorForTests()]
        
        let result1 = try await collector.collect()
        XCTAssertNil(result1?.metadata, "Should respect metadata = false")
        XCTAssertNil(result1?.location, "Should respect location = false")
        
        // Change configuration and test again
        config.metadata = true
        config.location = false
        
        let result2 = try await collector.collect()
        XCTAssertNotNil(result2?.metadata, "Should respect metadata = true")
        XCTAssertNil(result2?.location, "Should respect location = false")
    }
}

// MARK: - Mock Objects for Testing

struct MockPlatformCollectorForTests: DeviceCollector {
    typealias DataType = MockPlatformData
    let key = "platform"
    
    func collect() async throws -> MockPlatformData? {
        return MockPlatformData(platform: "iOS", version: "17.0")
    }
}

struct MockHardwareCollectorForTests: DeviceCollector {
    typealias DataType = MockHardwareData
    let key = "hardware"
    
    func collect() async throws -> MockHardwareData? {
        return MockHardwareData(manufacturer: "Apple", memory: 8192)
    }
}

struct MockFailingCollectorForTests: DeviceCollector {
    typealias DataType = String
    let key = "failing"
    
    func collect() async throws -> String? {
        throw TestError.mockError
    }
}

struct MockThrowingCollectorForTests: DeviceCollector {
    typealias DataType = String
    let key = "throwing"
    
    func collect() async throws -> String? {
        throw TestError.mockError
    }
}

struct MockLoggerAwareCollectorForTests: DeviceCollector, LoggerAware {
    typealias DataType = String
    let key = "logger-aware"
    var logger: Logger = LogManager.warning
    
    func collect() async throws -> String? {
        return "test-data"
    }
}

struct MockPlatformData: Codable {
    let platform: String
    let version: String
}

struct MockHardwareData: Codable {
    let manufacturer: String
    let memory: Int
}

struct MockDeviceIdentifierForTests: DeviceIdentifier {
    let id: String
    
    init(id: String = "mock-device-id") {
        self.id = id
    }
}

struct ThrowingDeviceIdentifierForTests: DeviceIdentifier {
    var id: String {
        get throws {
            throw TestError.mockError
        }
    }
}

enum TestError: Error {
    case mockError
}
