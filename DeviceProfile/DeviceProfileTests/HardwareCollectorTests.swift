// 
//  HardwareCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import UIKit
import AVFoundation
@testable import PingDeviceProfile

@MainActor
class HardwareCollectorTests: XCTestCase {
    
    var collector: HardwareCollector!
    
    override func setUp() async throws {
        try await super.setUp()
        collector = HardwareCollector()
    }
    
    override func tearDown() async throws {
        collector = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "hardware", "HardwareCollector should have correct key")
    }
    
    // MARK: - HardwareInfo Tests
    
    func testHardwareInfoInitialization() {
        let hardwareInfo = HardwareInfo()
        
        // Basic properties
        XCTAssertEqual(hardwareInfo.manufacturer, "Apple", "Manufacturer should be Apple")
        XCTAssertGreaterThan(hardwareInfo.memory, 0, "Memory should be positive")
        XCTAssertGreaterThan(hardwareInfo.cpu, 0, "CPU count should be positive")
        XCTAssertNotNil(hardwareInfo.display, "Display info should not be nil")
        XCTAssertNotNil(hardwareInfo.camera, "Camera info should not be nil")
    }
    
    func testHardwareInfoCPUValidation() {
        let hardwareInfo = HardwareInfo()
        
        // CPU count should be reasonable for iOS devices
        XCTAssertGreaterThan(hardwareInfo.cpu, 0, "CPU count should be positive")
        XCTAssertLessThan(hardwareInfo.cpu, 32, "CPU count should be reasonable")
        
        // Should match ProcessInfo
        let expectedCPUCount = ProcessInfo.processInfo.processorCount
        XCTAssertEqual(hardwareInfo.cpu, expectedCPUCount, "CPU count should match ProcessInfo")
    }
    
    func testHardwareInfoDisplayValidation() {
        let hardwareInfo = HardwareInfo()
        
        guard let display = hardwareInfo.display else {
            XCTFail("Display info should not be nil")
            return
        }
        
        // Check required keys
        XCTAssertNotNil(display["width"], "Display should have width")
        XCTAssertNotNil(display["height"], "Display should have height")
        XCTAssertNotNil(display["orientation"], "Display should have orientation")
        
        // Validate values
        if let width = display["width"] {
            XCTAssertGreaterThan(width, 0, "Display width should be positive")
            XCTAssertLessThan(width, 10000, "Display width should be reasonable")
        }
        
        if let height = display["height"] {
            XCTAssertGreaterThan(height, 0, "Display height should be positive")
            XCTAssertLessThan(height, 10000, "Display height should be reasonable")
        }
        
        if let orientation = display["orientation"] {
            XCTAssertTrue([0, 1].contains(orientation), "Orientation should be 0 or 1")
        }
    }
    
    func testHardwareInfoCameraValidation() {
        let hardwareInfo = HardwareInfo()
        
        guard let camera = hardwareInfo.camera else {
            XCTFail("Camera info should not be nil")
            return
        }
        
        // Check required keys
        XCTAssertNotNil(camera["numberOfCameras"], "Camera should have numberOfCameras")
        
        // Validate values
        if let cameraCount = camera["numberOfCameras"] {
            XCTAssertGreaterThanOrEqual(cameraCount, 0, "Camera count should be non-negative")
            XCTAssertLessThan(cameraCount, 10, "Camera count should be reasonable")
        }
    }
    
    func testHardwareInfoCodable() throws {
        let hardwareInfo = HardwareInfo()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(hardwareInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded HardwareInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(HardwareInfo.self, from: data)
        
        XCTAssertEqual(hardwareInfo.manufacturer, decodedInfo.manufacturer)
        XCTAssertEqual(hardwareInfo.memory, decodedInfo.memory)
        XCTAssertEqual(hardwareInfo.cpu, decodedInfo.cpu)
    }
    
    func testHardwareInfoJSONStructure() throws {
        let hardwareInfo = HardwareInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(hardwareInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        
        // Check required fields
        XCTAssertEqual(jsonObject?["manufacturer"] as? String, "Apple")
        XCTAssertNotNil(jsonObject?["memory"], "JSON should contain memory")
        XCTAssertNotNil(jsonObject?["cpu"], "JSON should contain cpu")
        XCTAssertNotNil(jsonObject?["display"], "JSON should contain display")
        XCTAssertNotNil(jsonObject?["camera"], "JSON should contain camera")
        
        // Validate nested structures
        if let display = jsonObject?["display"] as? [String: Any] {
            XCTAssertNotNil(display["width"], "Display should have width")
            XCTAssertNotNil(display["height"], "Display should have height")
            XCTAssertNotNil(display["orientation"], "Display should have orientation")
        }
        
        if let camera = jsonObject?["camera"] as? [String: Any] {
            XCTAssertNotNil(camera["numberOfCameras"], "Camera should have numberOfCameras")
        }
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "HardwareCollector.collect() should return a result")
        XCTAssertEqual(result?.manufacturer, "Apple", "Collected hardware should have Apple manufacturer")
    }
    
    func testCollectorCollectReturnsValidData() async {
        let result = await collector.collect()
        
        guard let hardwareInfo = result else {
            XCTFail("HardwareCollector should return HardwareInfo")
            return
        }
        
        // Validate all properties
        XCTAssertEqual(hardwareInfo.manufacturer, "Apple")
        XCTAssertGreaterThan(hardwareInfo.memory, 0)
        XCTAssertGreaterThan(hardwareInfo.cpu, 0)
        XCTAssertNotNil(hardwareInfo.display)
        XCTAssertNotNil(hardwareInfo.camera)
    }
    
    func testCollectorCollectConsistency() async {
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collect should return result")
        XCTAssertNotNil(result2, "Second collect should return result")
        
        // Hardware specs should be consistent
        XCTAssertEqual(result1?.manufacturer, result2?.manufacturer)
        XCTAssertEqual(result1?.memory, result2?.memory)
        XCTAssertEqual(result1?.cpu, result2?.cpu)
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    func testHardwareInfoInitializationPerformance() {
        measure {
            _ = HardwareInfo()
        }
    }
    
    // MARK: - Integration Tests
    
    func testHardwareCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let hardwareCollector = defaultCollectors.first { $0.key == "hardware" }
        
        XCTAssertNotNil(hardwareCollector, "Default collectors should include HardwareCollector")
        XCTAssertTrue(hardwareCollector is HardwareCollector,
                     "Default hardware collector should be HardwareCollector instance")
    }
    
    func testHardwareCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["hardware"], "Result should contain hardware data")
        
        // Verify the structure matches expectations
        if let hardwareData = result["hardware"] as? [String: Any] {
            XCTAssertEqual(hardwareData["manufacturer"] as? String, "Apple")
            XCTAssertNotNil(hardwareData["memory"], "Hardware data should have memory")
            XCTAssertNotNil(hardwareData["cpu"], "Hardware data should have cpu")
            XCTAssertNotNil(hardwareData["display"], "Hardware data should have display")
            XCTAssertNotNil(hardwareData["camera"], "Hardware data should have camera")
        } else {
            XCTFail("Hardware data should be a dictionary")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: HardwareInfo?.self) { group in
            let testCollector = HardwareCollector()
            for _ in 0..<iterations {
                group.addTask {
                    return await testCollector.collect()
                }
            }
            
            var results: [HardwareInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be identical (hardware specs don't change)
            let validResults = results.compactMap { $0 }
            if validResults.count > 1 {
                let first = validResults[0]
                for result in validResults {
                    XCTAssertEqual(result.manufacturer, first.manufacturer)
                    XCTAssertEqual(result.memory, first.memory)
                    XCTAssertEqual(result.cpu, first.cpu)
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: HardwareCollector?
        
        autoreleasepool {
            let localCollector = HardwareCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testDisplayOrientationValues() {
        let hardwareInfo = HardwareInfo()
        
        guard let display = hardwareInfo.display,
              let orientation = display["orientation"] else {
            XCTFail("Display orientation should be available")
            return
        }
        
        // Orientation should be 0 (landscape) or 1 (portrait)
        XCTAssertTrue([0, 1].contains(orientation), "Orientation should be 0 or 1")
    }
    
    func testMemoryCalculation() {
        let hardwareInfo = HardwareInfo()
        
        // Verify memory calculation matches ProcessInfo
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let expectedMemoryMB = Int64(physicalMemory / (1024 * 1024))
        
        XCTAssertEqual(hardwareInfo.memory, expectedMemoryMB,
                      "Memory should match ProcessInfo calculation")
    }
    
    func testCameraCountReasonableness() async {
        let hardwareInfo = HardwareInfo()
        
        guard let camera = hardwareInfo.camera,
              let cameraCount = camera["numberOfCameras"] else {
            XCTFail("Camera count should be available")
            return
        }
        
        // iOS devices typically have 1-4 cameras
        XCTAssertGreaterThanOrEqual(cameraCount, 0, "Camera count should be non-negative")
        XCTAssertLessThanOrEqual(cameraCount, 6, "Camera count should be reasonable")
    }
    
    // MARK: - Validation Helper Tests
    
    func testHardwareInfoEquality() {
        let info1 = HardwareInfo()
        let info2 = HardwareInfo()
        
        // Hardware info should be consistent across instances
        XCTAssertEqual(info1.manufacturer, info2.manufacturer)
        XCTAssertEqual(info1.memory, info2.memory)
        XCTAssertEqual(info1.cpu, info2.cpu)
    }
    
    func testDisplayDimensionsReasonable() {
        let hardwareInfo = HardwareInfo()
        
        guard let display = hardwareInfo.display,
              let width = display["width"],
              let height = display["height"] else {
            XCTFail("Display dimensions should be available")
            return
        }
        
        // iOS device screens are typically between 200-500 points in each dimension
        XCTAssertGreaterThan(width, 100, "Display width should be reasonable")
        XCTAssertLessThan(width, 2000, "Display width should not be excessive")
        
        XCTAssertGreaterThan(height, 100, "Display height should be reasonable")
        XCTAssertLessThan(height, 3000, "Display height should not be excessive")
        
        // One dimension should be larger than the other (aspect ratio check)
        XCTAssertNotEqual(width, height, "Width and height should typically differ")
    }
    
    // MARK: - System Integration Tests
    
    func testHardwareInfoMatchesSystemInfo() {
        let hardwareInfo = HardwareInfo()
        
        // CPU count should match system
        let systemCPUCount = ProcessInfo.processInfo.processorCount
        XCTAssertEqual(hardwareInfo.cpu, systemCPUCount, "CPU count should match system")
        
        // Memory should match system (within reasonable margin due to rounding)
        let systemMemory = ProcessInfo.processInfo.physicalMemory
        let systemMemoryMB = Int64(systemMemory / (1024 * 1024))
        XCTAssertEqual(hardwareInfo.memory, systemMemoryMB, "Memory should match system")
    }
    
    func testDisplayInfoMatchesUIScreen() {
        let hardwareInfo = HardwareInfo()
        
        guard let display = hardwareInfo.display else {
            XCTFail("Display info should be available")
            return
        }
        
        let screenBounds = UIScreen.main.bounds
        
        // Should match UIScreen dimensions (allowing for orientation)
        let screenWidth = Int(screenBounds.width)
        let screenHeight = Int(screenBounds.height)
        
        if let displayWidth = display["width"], let displayHeight = display["height"] {
            // Dimensions should match in some orientation
            let dimensionsMatch = (displayWidth == screenWidth && displayHeight == screenHeight) ||
                                (displayWidth == screenHeight && displayHeight == screenWidth)
            
            XCTAssertTrue(dimensionsMatch, "Display dimensions should match UIScreen bounds")
        }
    }
}
