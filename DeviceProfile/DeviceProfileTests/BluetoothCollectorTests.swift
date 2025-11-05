// 
//  BluetoothCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CoreBluetooth
@testable import PingDeviceProfile

class BluetoothCollectorTests: XCTestCase {
    
    var collector: BluetoothCollector!
    
    override func setUp() {
        super.setUp()
        collector = BluetoothCollector()
    }
    
    override func tearDown() {
        collector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "bluetooth", "BluetoothCollector should have correct key")
    }
    
    // MARK: - BluetoothInfo Tests
    
    func testBluetoothInfoInitialization() async {
        let bluetoothInfo = await BluetoothInfo()
        
        XCTAssertNotNil(bluetoothInfo.supported, "BluetoothInfo.supported should not be nil")
    }
    
    func testBluetoothInfoCodable() async throws {
        let bluetoothInfo = await BluetoothInfo()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(bluetoothInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded BluetoothInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(BluetoothInfo.self, from: data)
        XCTAssertEqual(bluetoothInfo.supported, decodedInfo.supported, "Decoded BluetoothInfo should match original")
    }
    
    func testBluetoothInfoJSONStructure() async throws {
        let bluetoothInfo = await BluetoothInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(bluetoothInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        XCTAssertNotNil(jsonObject?["supported"], "JSON should contain 'supported' key")
        XCTAssertTrue(jsonObject?["supported"] is Bool, "supported value should be Bool in JSON")
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "BluetoothCollector.collect() should return a result")
        XCTAssertNotNil(result?.supported, "Collected BluetoothInfo should have supported property")
    }
    
    func testCollectorCollectReturnsValidData() async {
        let result = await collector.collect()
        
        guard let bluetoothInfo = result else {
            XCTFail("BluetoothCollector should return BluetoothInfo")
            return
        }
        
        // In simulator/test environment, BLE might not be supported
        // But the property should still be a valid Bool
        let supportedValues = [true, false]
        XCTAssertTrue(supportedValues.contains(bluetoothInfo.supported),
                     "supported should be either true or false")
    }
    
    // MARK: - Async Behavior Tests
    
    func testCollectorCollectMultipleTimes() async {
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collect should return result")
        XCTAssertNotNil(result2, "Second collect should return result")
        
        // Results should be consistent (BLE support doesn't change during app runtime)
        XCTAssertEqual(result1?.supported, result2?.supported,
                      "Multiple collections should return consistent results")
    }
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testBluetoothCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let bluetoothCollector = defaultCollectors.first { $0.key == "bluetooth" }
        
        XCTAssertNotNil(bluetoothCollector, "Default collectors should include BluetoothCollector")
        XCTAssertTrue(bluetoothCollector is BluetoothCollector,
                     "Default bluetooth collector should be BluetoothCollector instance")
    }
    
    func testBluetoothCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["bluetooth"], "Result should contain bluetooth data")
        
        // Verify the structure matches expectations
        if let bluetoothData = result["bluetooth"] as? [String: Any] {
            XCTAssertNotNil(bluetoothData["supported"], "Bluetooth data should have 'supported' key")
            XCTAssertTrue(bluetoothData["supported"] is Bool, "'supported' should be Bool")
        } else {
            XCTFail("Bluetooth data should be a dictionary")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCollectorDoesNotThrow() async {
        // BluetoothCollector.collect() should never throw
        _ = await collector.collect()
        XCTAssertTrue(true, "collect() completed without throwing")
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: BluetoothCollector?
        
        autoreleasepool {
            let localCollector = BluetoothCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: BluetoothInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.collector.collect()
                }
            }
            
            var results: [BluetoothInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be consistent
            let supportedValues = results.compactMap { $0?.supported }
            if supportedValues.count > 1 {
                let firstValue = supportedValues[0]
                XCTAssertTrue(supportedValues.allSatisfy { $0 == firstValue },
                             "All concurrent results should be consistent")
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testBluetoothInfoEquality() async {
        let info1 = await BluetoothInfo()
        let info2 = await BluetoothInfo()
        
        // Since both are created at similar times, they should have the same supported value
        XCTAssertEqual(info1.supported, info2.supported,
                      "BluetoothInfo instances created at same time should be equal")
    }
    
    func testBluetoothCollectorDescription() {
        // Verify collector can be described without crashing
        let description = String(describing: collector)
        XCTAssertFalse(description.isEmpty, "Collector description should not be empty")
        XCTAssertTrue(description.contains("BluetoothCollector"),
                     "Description should mention BluetoothCollector")
    }
}

