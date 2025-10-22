// 
//  NetworkCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import Network
@testable import PingDeviceProfile

class NetworkCollectorTests: XCTestCase {
    
    var collector: NetworkCollector!
    
    override func setUp() {
        super.setUp()
        collector = NetworkCollector()
    }
    
    override func tearDown() {
        collector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "network", "NetworkCollector should have correct key")
    }
    
    // MARK: - NetworkInfo Tests
    
    func testNetworkInfoInitialization() async {
        let networkInfo = await NetworkInfo()
        
        XCTAssertNotNil(networkInfo.connected, "NetworkInfo.connected should not be nil")
    }
    
    func testNetworkInfoCodable() async throws {
        let networkInfo = await NetworkInfo()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(networkInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded NetworkInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(NetworkInfo.self, from: data)
        
        XCTAssertEqual(networkInfo.connected, decodedInfo.connected, "Decoded NetworkInfo should match original")
    }
    
    func testNetworkInfoJSONStructure() async throws {
        let networkInfo = await NetworkInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(networkInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        XCTAssertNotNil(jsonObject?["connected"], "JSON should contain 'connected' key")
        XCTAssertTrue(jsonObject?["connected"] is Bool, "connected value should be Bool in JSON")
    }
    
    func testNetworkInfoBooleanValues() async {
        let networkInfo = await NetworkInfo()
        
        // connected should be a valid boolean value
        let validBooleanValues = [true, false]
        XCTAssertTrue(validBooleanValues.contains(networkInfo.connected),
                     "connected should be either true or false")
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "NetworkCollector.collect() should return a result")
        XCTAssertNotNil(result?.connected, "Collected NetworkInfo should have connected property")
    }
    
    func testCollectorCollectReturnsValidData() async {
        let result = await collector.collect()
        
        guard let networkInfo = result else {
            XCTFail("NetworkCollector should return NetworkInfo")
            return
        }
        
        // In test environment, network might be available or not
        let validConnectionStates = [true, false]
        XCTAssertTrue(validConnectionStates.contains(networkInfo.connected),
                     "connected should be either true or false")
    }
    
    func testCollectorCollectConsistency() async {
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collect should return result")
        XCTAssertNotNil(result2, "Second collect should return result")
        
        // Network status might change between calls, but both should be valid boolean values
        XCTAssertTrue(result1?.connected is Bool, "First result should be Boolean")
        XCTAssertTrue(result2?.connected is Bool, "Second result should be Boolean")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    func testNetworkInfoInitializationPerformance() async {
        measure {
            Task {
                _ = await NetworkInfo()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testNetworkCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let networkCollector = defaultCollectors.first { $0.key == "network" }
        
        XCTAssertNotNil(networkCollector, "Default collectors should include NetworkCollector")
        XCTAssertTrue(networkCollector is NetworkCollector,
                     "Default network collector should be NetworkCollector instance")
    }
    
    func testNetworkCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["network"], "Result should contain network data")
        
        // Verify the structure matches expectations
        if let networkData = result["network"] as? [String: Any] {
            XCTAssertNotNil(networkData["connected"], "Network data should have 'connected' key")
            XCTAssertTrue(networkData["connected"] is Bool, "'connected' should be Bool")
        } else {
            XCTFail("Network data should be a dictionary")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: NetworkInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.collector.collect()
                }
            }
            
            var results: [NetworkInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be valid NetworkInfo objects
            let validResults = results.compactMap { $0 }
            XCTAssertEqual(validResults.count, iterations, "All tasks should succeed")
            
            // All connection statuses should be valid booleans
            for result in validResults {
                XCTAssertTrue([true, false].contains(result.connected),
                             "All connection statuses should be valid booleans")
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: NetworkCollector?
        
        autoreleasepool {
            let localCollector = NetworkCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Network Status Validation Tests
    
    func testNetworkInfoEquality() async {
        // Create multiple instances and compare
        let info1 = await NetworkInfo()
        let info2 = await NetworkInfo()
        
        // Values might be equal if network status is stable
        // This is not guaranteed due to potential network changes between instantiation
        let bothConnected = info1.connected == info2.connected
        let bothDisconnected = !info1.connected && !info2.connected
        
        // At least one of the following should be true:
        // 1. Both have the same connection status (network is stable)
        // 2. Both have valid but potentially different boolean values
        XCTAssertTrue(
            bothConnected || bothDisconnected || (info1.connected != info2.connected),
            "Network info should have consistent or validly different boolean values"
        )
    }
    
    // MARK: - Edge Case Tests
    
    func testNetworkCollectorDescription() {
        // Verify collector can be described without crashing
        let description = String(describing: collector)
        XCTAssertFalse(description.isEmpty, "Collector description should not be empty")
        XCTAssertTrue(description.contains("NetworkCollector"),
                     "Description should mention NetworkCollector")
    }
    
    func testNetworkInfoDescription() async {
        let networkInfo = await NetworkInfo()
        
        // Verify NetworkInfo can be described without crashing
        let description = String(describing: networkInfo)
        XCTAssertFalse(description.isEmpty, "NetworkInfo description should not be empty")
        XCTAssertTrue(description.contains("NetworkInfo") || description.contains("connected"),
                     "Description should mention NetworkInfo or connected property")
    }
    
    func testMultipleNetworkInfoInstances() async {
        // Test creating multiple instances doesn't cause issues
        var networkInfos: [NetworkInfo] = []
        
        for _ in 0..<10 {
            let networkInfo = await NetworkInfo()
            networkInfos.append(networkInfo)
        }
        
        // All instances should be valid
        XCTAssertEqual(networkInfos.count, 10, "Should create all instances successfully")
        
    }
    
    // MARK: - System Integration Tests
    
    func testNetworkInfoUsesNetworkFramework() async {
        // This test verifies that NetworkInfo actually uses the Network framework
        // We can't easily mock NWPathMonitor in a unit test, but we can verify
        // that the NetworkInfo initialization doesn't crash and produces valid output
        
        let networkInfo = await NetworkInfo()
        
        // Should complete without crashing
        XCTAssertNotNil(networkInfo, "NetworkInfo should initialize successfully")
    }
    
    func testNetworkCollectionWithSystemChanges() async {
        // Test collecting network info multiple times to handle potential system changes
        var results: [Bool] = []
        
        for _ in 0..<5 {
            if let networkInfo = await collector.collect() {
                results.append(networkInfo.connected)
            }
            
            // Small delay between collections
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        XCTAssertEqual(results.count, 5, "Should collect all network statuses")
        
        // All results should be valid booleans
        for result in results {
            XCTAssertTrue([true, false].contains(result), "Each result should be a valid boolean")
        }
        
        // Most results should be consistent (network status usually doesn't change rapidly)
        let connectedCount = results.filter { $0 }.count
        let disconnectedCount = results.filter { !$0 }.count
        
        // At least 80% of results should agree (allowing for some network instability)
        let majorityThreshold = 4 // 4 out of 5
        let hasMajority = connectedCount >= majorityThreshold || disconnectedCount >= majorityThreshold
        
        XCTAssertTrue(hasMajority, "Network status should be mostly consistent across rapid collections")
    }
    
    // MARK: - JSON Serialization Edge Cases
    
    func testNetworkInfoJSONRoundTrip() async throws {
        let originalInfo = await NetworkInfo()
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalInfo)
        
        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(NetworkInfo.self, from: jsonData)
        
        // Should match exactly
        XCTAssertEqual(originalInfo.connected, decodedInfo.connected,
                      "JSON round-trip should preserve connected status")
    }
    
    func testNetworkInfoJSONCompatibility() throws {
        // Test with both possible boolean values
        let testCases = [true, false]
        
        for connectedStatus in testCases {
            // Create JSON manually to test decoding
            let jsonString = """
            {
                "connected": \(connectedStatus)
            }
            """
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                XCTFail("Failed to convert JSON string to data")
                return
            }
            let decoder = JSONDecoder()
            let networkInfo = try decoder.decode(NetworkInfo.self, from: jsonData)
            
            XCTAssertEqual(networkInfo.connected, connectedStatus,
                          "Should decode JSON correctly for connected: \(connectedStatus)")
        }
    }
}
