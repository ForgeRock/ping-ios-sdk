//
//  BluetoothCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CoreBluetooth
@testable import PingDeviceProfile

class BluetoothCollectorTests: XCTestCase {
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        let collector = BluetoothCollector(stateProvider: MockBluetoothStateProvider(mockState: .poweredOn))
        XCTAssertEqual(collector.key, "bluetooth", "BluetoothCollector should have correct key")
    }
    
    // MARK: - Mock-Based Tests (No System Prompt)
    
    func testCollectorCollectWithMockedStatePoweredOn() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .poweredOn)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertTrue(result?.supported ?? false, "Device should support BLE when powered on")
    }
    
    func testCollectorCollectWithMockedStatePoweredOff() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .poweredOff)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertTrue(result?.supported ?? false, "Device should support BLE when powered off")
    }
    
    func testCollectorCollectWithMockedStateUnsupported() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .unsupported)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertFalse(result?.supported ?? true, "Device should not support BLE when unsupported")
    }
    
    func testCollectorCollectWithMockedStateUnauthorized() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .unauthorized)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertFalse(result?.supported ?? true, "Device should not support BLE when unauthorized")
    }
    
    func testCollectorCollectWithMockedStateUnknown() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .unknown)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertFalse(result?.supported ?? true, "Device should not support BLE when unknown")
    }
    
    func testCollectorCollectWithMockedStateResetting() async {
        let mockProvider = MockBluetoothStateProvider(mockState: .resetting)
        let collector = BluetoothCollector(stateProvider: mockProvider)
        
        let result = await collector.collect()
        XCTAssertFalse(result?.supported ?? true, "Device should not support BLE when resetting")
    }
    
    // MARK: - Codable Tests
    
    func testBluetoothInfoCodable() async throws {
        let bluetoothInfo = BluetoothInfo(supported: true)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(bluetoothInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded BluetoothInfo should not be empty")
        
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(BluetoothInfo.self, from: data)
        XCTAssertEqual(bluetoothInfo.supported, decodedInfo.supported)
    }
    
    func testBluetoothInfoJSONStructure() throws {
        let bluetoothInfo = BluetoothInfo(supported: true)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(bluetoothInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        XCTAssertTrue(jsonObject?["supported"] is Bool, "'supported' should be Bool in JSON")
    }
    
    // MARK: - State Validation Tests
    
    func testAllBluetoothStatesHandled() async {
        let allStates: [CBManagerState] = [.unknown, .resetting, .unsupported, .unauthorized, .poweredOff, .poweredOn]
        
        for state in allStates {
            let mockProvider = MockBluetoothStateProvider(mockState: state)
            let collector = BluetoothCollector(stateProvider: mockProvider)
            
            let info = await collector.collect()
            let expected = state == .poweredOn || state == .poweredOff
            XCTAssertEqual(info?.supported, expected,
                           "State \(state) should result in supported=\(expected)")
        }
    }
    
    // MARK: - Concurrent Tests
    
    func testConcurrentCollectionWithMockedStates() async {
        let states: [CBManagerState] = [.poweredOn, .poweredOff, .unsupported, .unauthorized]
        
        await withTaskGroup(of: BluetoothInfo?.self) { group in
            for state in states {
                group.addTask {
                    let mockProvider = MockBluetoothStateProvider(mockState: state)
                    let collector = BluetoothCollector(stateProvider: mockProvider)
                    return await collector.collect()
                }
            }
            
            var results: [BluetoothInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, states.count, "Should complete all concurrent tasks")
        }
    }
}

// MARK: - Mock Implementation

/// Mock Bluetooth state provider for testing (no system prompts)
struct MockBluetoothStateProvider: BluetoothStateProvider {
    var mockState: CBManagerState = .poweredOn
    
    func getBluetoothSupported() async -> Bool {
        let isBLESupported = mockState == .poweredOn || mockState == .poweredOff
        return isBLESupported
    }
}
