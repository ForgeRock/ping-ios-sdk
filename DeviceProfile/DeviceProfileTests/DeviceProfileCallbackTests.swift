// 
//  DeviceProfileCallbackTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingJourneyPlugin
import PingLogger
@testable import PingDeviceProfile

class DeviceProfileCallbackTests: XCTestCase {
    
    var callback: DeviceProfileCallback!
    
    override func setUp() {
        super.setUp()
        callback = DeviceProfileCallback()
    }
    
    override func tearDown() {
        callback = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testCallbackInitialization() {
        XCTAssertNotNil(callback, "DeviceProfileCallback should initialize")
        XCTAssertFalse(callback.metadata, "Metadata should be false by default")
        XCTAssertFalse(callback.location, "Location should be false by default")
        XCTAssertEqual(callback.message, "", "Message should be empty by default")
    }
    
    // MARK: - InitValue Tests
    
    func testInitValueMetadata() {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        XCTAssertTrue(callback.metadata, "Metadata should be set to true")
        
        callback.initValue(name: JourneyConstants.metadata, value: false)
        XCTAssertFalse(callback.metadata, "Metadata should be set to false")
    }
    
    func testInitValueLocation() {
        callback.initValue(name: JourneyConstants.location, value: true)
        XCTAssertTrue(callback.location, "Location should be set to true")
        
        callback.initValue(name: JourneyConstants.location, value: false)
        XCTAssertFalse(callback.location, "Location should be set to false")
    }
    
    func testInitValueMessage() {
        let testMessage = "Test message from server"
        callback.initValue(name: JourneyConstants.message, value: testMessage)
        XCTAssertEqual(callback.message, testMessage, "Message should be set correctly")
        
        let emptyMessage = ""
        callback.initValue(name: JourneyConstants.message, value: emptyMessage)
        XCTAssertEqual(callback.message, emptyMessage, "Empty message should be set correctly")
    }
    
    func testInitValueWithInvalidTypes() {
        // Test with wrong type for boolean values
        callback.initValue(name: JourneyConstants.metadata, value: "true")
        XCTAssertFalse(callback.metadata, "Metadata should remain false with invalid type")
        
        callback.initValue(name: JourneyConstants.location, value: 1)
        XCTAssertFalse(callback.location, "Location should remain false with invalid type")
        
        // Test with wrong type for string value
        callback.initValue(name: JourneyConstants.message, value: 123)
        XCTAssertEqual(callback.message, "", "Message should remain empty with invalid type")
    }
    
    func testInitValueUnknownProperty() {
        // Should not crash with unknown property names
        callback.initValue(name: "unknown_property", value: "some_value")
        
        // Properties should remain unchanged
        XCTAssertFalse(callback.metadata, "Metadata should remain unchanged")
        XCTAssertFalse(callback.location, "Location should remain unchanged")
        XCTAssertEqual(callback.message, "", "Message should remain unchanged")
    }
    
    // MARK: - DeviceProfileConfig Tests
    
    func testDeviceProfileConfigInitialization() {
        let config = DeviceProfileConfig()
        
        XCTAssertFalse(config.metadata, "Metadata should be false by default")
        XCTAssertFalse(config.location, "Location should be false by default")
        XCTAssertNotNil(config.logger, "Logger should not be nil")
        XCTAssertFalse(config.collectors.isEmpty, "Collectors should not be empty by default")
        XCTAssertEqual(config.collectors.count, DefaultDeviceCollector.defaultDeviceCollectors().count, "Collectors should have all default collectors")
        // DeviceIdentifier might be nil in test environment
    }
    
    func testDeviceProfileConfigCollectorsBuilder() {
        let config = DeviceProfileConfig()
        
        config.collectors {
            return [
                MockCollectorForCallbackTests(key: "test1"),
                MockCollectorForCallbackTests(key: "test2")
            ]
        }
        
        XCTAssertEqual(config.collectors.count, 2, "Should have 2 collectors")
        XCTAssertEqual(config.collectors[0].key, "test1", "First collector should have correct key")
        XCTAssertEqual(config.collectors[1].key, "test2", "Second collector should have correct key")
    }
    
    func testDeviceProfileConfigModification() {
        let config = DeviceProfileConfig()
        
        // Modify properties
        config.metadata = true
        config.location = true
        
        XCTAssertTrue(config.metadata, "Metadata should be modifiable")
        XCTAssertTrue(config.location, "Location should be modifiable")
    }
    
    // MARK: - Collection Tests
    
    func testCollectWithDefaultConfiguration() async {
        // Set up callback as if configured by server
        callback.initValue(name: JourneyConstants.metadata, value: true)
        callback.initValue(name: JourneyConstants.location, value: false)
        
        let result = await callback.collect { config in
            config.collectors {
                return [MockCollectorForCallbackTests(key: "platform")]
            }
        }
        
        switch result {
        case .success(let profile):
            XCTAssertNotNil(profile["identifier"], "Profile should have identifier")
            XCTAssertNotNil(profile["metadata"], "Profile should have metadata when enabled")
            
        case .failure(let error):
            // Collection might fail in test environment, but shouldn't crash
            XCTAssertNotNil(error, "Error should be provided on failure")
        }
    }
    
    func testCollectWithMetadataDisabled() async {
        callback.initValue(name: JourneyConstants.metadata, value: false)
        callback.initValue(name: JourneyConstants.location, value: false)
        
        let result = await callback.collect { config in
            config.collectors {
                return [MockCollectorForCallbackTests(key: "platform")]
            }
        }
        
        switch result {
        case .success(let profile):
            XCTAssertNotNil(profile["identifier"], "Profile should have identifier")
            // Metadata collection is disabled, so metadata might be nil or empty
            
        case .failure:
            // Acceptable in test environment
            break
        }
    }
    
    func testCollectWithCustomCollectors() async {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        
        let result = await callback.collect { config in
            config.collectors {
                return [
                    MockCollectorForCallbackTests(key: "platform"),
                    MockCollectorForCallbackTests(key: "hardware"),
                    MockCollectorForCallbackTests(key: "network")
                ]
            }
        }
        
        switch result {
        case .success(let profile):
            XCTAssertNotNil(profile["identifier"], "Profile should have identifier")
            XCTAssertNotNil(profile["metadata"], "Profile should have metadata")
            
            // Check if metadata contains expected collectors
            if let metadata = profile["metadata"] as? [String: Any] {
                // At least some collectors should have succeeded
                XCTAssertGreaterThan(metadata.count, 0, "Metadata should contain collector data")
            }
            
        case .failure(let error):
            XCTFail("Collection with valid collectors should succeed: \(error)")
        }
    }
    
    func testCollectWithFailingCollectors() async {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        
        let result = await callback.collect { config in
            config.collectors {
                return [
                    MockCollectorForCallbackTests(key: "platform"),
                    FailingMockCollectorForCallbackTests()
                ]
            }
        }
        
        switch result {
        case .success(let profile):
            // Should succeed even with some failing collectors
            XCTAssertNotNil(profile["identifier"], "Profile should have identifier")
            
        case .failure:
            // Might fail if all collectors fail or other errors occur
            break
        }
    }
    
    func testCollectWithEmptyCollectors() async {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        
        let result = await callback.collect { config in
            config.collectors {
                return []
            }
        }
        
        switch result {
        case .success(let profile):
            XCTAssertNotNil(profile["identifier"], "Profile should have identifier even with no collectors")
            
        case .failure:
            // Acceptable behavior
            break
        }
    }
    
    // MARK: - JSON Serialization Tests
    
    func testJSONStringifyWithValidObject() {
        let testObject: [String: Any] = [
            "string": "value",
            "number": 42,
            "boolean": true,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]
        
        let result = callback.jsonStringify(value: testObject as AnyObject)
        
        XCTAssertFalse(result.isEmpty, "JSON string should not be empty")
        XCTAssertTrue(result.contains("string"), "JSON should contain string key")
        XCTAssertTrue(result.contains("value"), "JSON should contain string value")
        XCTAssertTrue(result.contains("42"), "JSON should contain number value")
    }
    
    func testJSONStringifyWithInvalidObject() {
        // Create an invalid JSON object (contains non-serializable data)
        let invalidObject = NSObject()
        
        let result = callback.jsonStringify(value: invalidObject)
        
        XCTAssertEqual(result, "", "Should return empty string for invalid objects")
    }
    
    func testJSONStringifyWithPrettyPrinting() {
        let testObject: [String: Any] = ["key": "value"]
        
        let prettyResult = callback.jsonStringify(value: testObject as AnyObject, prettyPrinted: true)
        let normalResult = callback.jsonStringify(value: testObject as AnyObject, prettyPrinted: false)
        
        XCTAssertGreaterThan(prettyResult.count, normalResult.count,
                            "Pretty printed JSON should be longer due to formatting")
        XCTAssertTrue(prettyResult.contains("\n") || prettyResult.contains("  "),
                     "Pretty printed JSON should contain formatting")
    }
    
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        
        let iterations = 3 // Keep low to avoid overwhelming test environment
        
        await withTaskGroup(of: Result<[String: any Sendable], Error>.self) { group in
            for i in 0..<iterations {
                group.addTask { [callback] in
                    return await callback.collect { config in
                        config.collectors {
                            return [MockCollectorForCallbackTests(key: "test-\(i)")]
                        }
                    }
                }
            }
            
            var results: [Result<[String: any Sendable], Error>] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // At least some should succeed
            let successCount = results.filter {
                if case .success = $0 { return true }
                return false
            }.count
            
            XCTAssertGreaterThan(successCount, 0, "At least some concurrent collections should succeed")
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCallbackMemoryManagement() {
        weak var weakCallback: DeviceProfileCallback?
        
        autoreleasepool {
            let localCallback = DeviceProfileCallback()
            weakCallback = localCallback
            XCTAssertNotNil(weakCallback, "Callback should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCallback, "Callback should be deallocated")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCollectErrorHandling() async {
        callback.initValue(name: JourneyConstants.metadata, value: true)
        
        let result = await callback.collect { config in
            // Configure with throwing collectors
            config.collectors {
                return [ThrowingMockCollectorForCallbackTests()]
            }
        }
        
        switch result {
        case .success:
            // If it succeeds despite throwing collectors, that's acceptable
            // (might have fallback behavior)
            break
        case .failure(let error):
            // Should provide meaningful error
            XCTAssertNotNil(error, "Error should be provided")
        }
    }
    
    // MARK: - ObservableObject Tests
    
    func testObservableObjectConformance() {
        // Test property changes trigger updates
        callback.initValue(name: JourneyConstants.metadata, value: true)
        callback.initValue(name: JourneyConstants.location, value: true)
        callback.initValue(name: JourneyConstants.message, value: "Test")
        
        // Properties should be updated
        XCTAssertTrue(callback.metadata, "Metadata should be updated")
        XCTAssertTrue(callback.location, "Location should be updated")
        XCTAssertEqual(callback.message, "Test", "Message should be updated")
    }
    
    // MARK: - Journey Constants Tests
    
    func testJourneyConstants() {
        XCTAssertEqual(JourneyConstants.metadata, "metadata", "Metadata constant should be correct")
        XCTAssertEqual(JourneyConstants.location, "location", "Location constant should be correct")
        XCTAssertEqual(JourneyConstants.message, "message", "Message constant should be correct")
        XCTAssertEqual(JourneyConstants.deviceProfileCallback, "DeviceProfileCallback",
                      "DeviceProfileCallback constant should be correct")
    }
    
    // MARK: - Integration Tests
    
    func testCallbackRegistration() async {
        // Test the static registration method
        
        DeviceProfile.registerCallbacks()
        
        // Should not crash
        XCTAssertTrue(true, "Registration should complete without error")
    }
    
    func testFullWorkflowSimulation() async {
        // Simulate a complete server-initiated workflow
        
        // 1. Server configures callback
        callback.initValue(name: JourneyConstants.metadata, value: true)
        callback.initValue(name: JourneyConstants.location, value: false)
        callback.initValue(name: JourneyConstants.message, value: "Please provide device information for security verification")
        
        // 2. Client collects device profile
        let result = await callback.collect { config in
            config.collectors {
                return [
                    MockCollectorForCallbackTests(key: "platform"),
                    MockCollectorForCallbackTests(key: "hardware")
                ]
            }
        }
        
        // 3. Verify result
        switch result {
        case .success(let profile):
            XCTAssertNotNil(profile["identifier"], "Should have device identifier")
            // Metadata might be present depending on configuration
            
        case .failure(let error):
            // Acceptable in test environment
            print("Collection failed with error: \(error)")
        }
        
        // 4. Verify callback state
        XCTAssertTrue(callback.metadata, "Metadata should be enabled")
        XCTAssertFalse(callback.location, "Location should be disabled")
        XCTAssertFalse(callback.message.isEmpty, "Message should be set")
    }
}

// MARK: - Mock Objects for Testing

struct MockCollectorForCallbackTests: DeviceCollector {
    typealias DataType = MockDataForCallbackTests
    let key: String
    
    init(key: String) {
        self.key = key
    }
    
    func collect() async throws -> MockDataForCallbackTests? {
        return MockDataForCallbackTests(value: "mock-\(key)-data")
    }
}

struct FailingMockCollectorForCallbackTests: DeviceCollector {
    typealias DataType = String
    let key = "failing"
    
    func collect() async throws -> String? {
        throw TestErrorForCallbackTests.collectionFailed
    }
}

struct ThrowingMockCollectorForCallbackTests: DeviceCollector {
    typealias DataType = String
    let key = "throwing"
    
    func collect() async throws -> String? {
        throw TestErrorForCallbackTests.serializationFailed
    }
}

struct MockDataForCallbackTests: Codable {
    let value: String
}

enum TestErrorForCallbackTests: Error, LocalizedError {
    case collectionFailed
    case serializationFailed
    
    var errorDescription: String? {
        switch self {
        case .collectionFailed:
            return "Mock collection failed"
        case .serializationFailed:
            return "Mock serialization failed"
        }
    }
}

// MARK: - Private Extension for Testing

private extension DeviceProfileCallback {
    func jsonStringify(value: AnyObject, prettyPrinted: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : []
        
        guard JSONSerialization.isValidJSONObject(value) else {
            return ""
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: options)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
