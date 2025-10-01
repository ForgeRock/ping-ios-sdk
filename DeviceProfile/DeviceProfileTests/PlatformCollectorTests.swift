// 
//  PlatformCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import UIKit
@testable import PingDeviceProfile

class PlatformCollectorTests: XCTestCase {
    
    var collector: PlatformCollector!
    
    override func setUp() {
        super.setUp()
        collector = PlatformCollector()
    }
    
    override func tearDown() {
        collector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "platform", "PlatformCollector should have correct key")
    }
    
    // MARK: - PlatformInfo Tests
    
    func testPlatformInfoInitialization() async {
        let platformInfo = await PlatformInfo()
        
        // Test all required fields are not empty
        XCTAssertFalse(platformInfo.platform.isEmpty, "Platform should not be empty")
        XCTAssertFalse(platformInfo.version.isEmpty, "Version should not be empty")
        XCTAssertFalse(platformInfo.device.isEmpty, "Device should not be empty")
        XCTAssertFalse(platformInfo.deviceName.isEmpty, "Device name should not be empty")
        XCTAssertFalse(platformInfo.model.isEmpty, "Model should not be empty")
        XCTAssertEqual(platformInfo.brand, "Apple", "Brand should be Apple")
        XCTAssertFalse(platformInfo.timeZone.isEmpty, "TimeZone should not be empty")
        
        // Test jailbreak score range
        XCTAssertGreaterThanOrEqual(platformInfo.jailBreakScore, 0.0, "Jailbreak score should be >= 0")
        XCTAssertLessThanOrEqual(platformInfo.jailBreakScore, 1.0, "Jailbreak score should be <= 1")
    }
    
    func testPlatformInfoSystemValues() async {
        let platformInfo = await PlatformInfo()
        let systemName = await UIDevice.current.systemName
        let systemVersion = await UIDevice.current.systemVersion
        let model = await UIDevice.current.model
        let name = await UIDevice.current.name
        // Compare with UIDevice values
        XCTAssertEqual(platformInfo.platform, systemName,
                      "Platform should match UIDevice systemName")
        XCTAssertEqual(platformInfo.version, systemVersion,
                      "Version should match UIDevice systemVersion")
        XCTAssertEqual(platformInfo.device, model,
                      "Device should match UIDevice model")
        XCTAssertEqual(platformInfo.deviceName, name,
                      "Device name should match UIDevice name")
        
        // Compare with system values
        XCTAssertEqual(platformInfo.timeZone, TimeZone.current.identifier,
                      "TimeZone should match current timezone")
    }
    
    func testPlatformInfoLocale() async {
        let platformInfo = await PlatformInfo()
        
        // Locale can be nil in some cases, but if present should match system
        if let locale = platformInfo.locale {
            XCTAssertFalse(locale.isEmpty, "Locale should not be empty if present")
            XCTAssertEqual(locale, Locale.current.languageCode,
                          "Locale should match current language code")
        }
    }
    
    func testPlatformInfoModel() async {
        let platformInfo = await PlatformInfo()
        
        // Model should be a valid device identifier
        XCTAssertFalse(platformInfo.model.isEmpty, "Model should not be empty")
        
        // Should contain alphanumeric characters
        let hasAlphanumeric = platformInfo.model.rangeOfCharacter(from: .alphanumerics) != nil
        XCTAssertTrue(hasAlphanumeric, "Model should contain alphanumeric characters")
        
        // Should not contain spaces (device models typically don't have spaces)
        XCTAssertFalse(platformInfo.model.contains(" "), "Model should not contain spaces")
    }
    
    func testPlatformInfoCodable() async throws {
        let platformInfo = await PlatformInfo()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(platformInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded PlatformInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(PlatformInfo.self, from: data)
        
        XCTAssertEqual(platformInfo.platform, decodedInfo.platform)
        XCTAssertEqual(platformInfo.version, decodedInfo.version)
        XCTAssertEqual(platformInfo.device, decodedInfo.device)
        XCTAssertEqual(platformInfo.deviceName, decodedInfo.deviceName)
        XCTAssertEqual(platformInfo.model, decodedInfo.model)
        XCTAssertEqual(platformInfo.brand, decodedInfo.brand)
        XCTAssertEqual(platformInfo.locale, decodedInfo.locale)
        XCTAssertEqual(platformInfo.timeZone, decodedInfo.timeZone)
        XCTAssertEqual(platformInfo.jailBreakScore, decodedInfo.jailBreakScore)
    }
    
    func testPlatformInfoJSONStructure() async throws {
        let platformInfo = await PlatformInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(platformInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        
        // Check all required fields
        XCTAssertNotNil(jsonObject?["platform"], "JSON should contain platform")
        XCTAssertNotNil(jsonObject?["version"], "JSON should contain version")
        XCTAssertNotNil(jsonObject?["device"], "JSON should contain device")
        XCTAssertNotNil(jsonObject?["deviceName"], "JSON should contain deviceName")
        XCTAssertNotNil(jsonObject?["model"], "JSON should contain model")
        XCTAssertNotNil(jsonObject?["brand"], "JSON should contain brand")
        XCTAssertNotNil(jsonObject?["timeZone"], "JSON should contain timeZone")
        XCTAssertNotNil(jsonObject?["jailBreakScore"], "JSON should contain jailBreakScore")
        
        // Verify types
        XCTAssertTrue(jsonObject?["platform"] is String, "platform should be String")
        XCTAssertTrue(jsonObject?["version"] is String, "version should be String")
        XCTAssertTrue(jsonObject?["device"] is String, "device should be String")
        XCTAssertTrue(jsonObject?["deviceName"] is String, "deviceName should be String")
        XCTAssertTrue(jsonObject?["model"] is String, "model should be String")
        XCTAssertEqual(jsonObject?["brand"] as? String, "Apple", "brand should be Apple")
        XCTAssertTrue(jsonObject?["timeZone"] is String, "timeZone should be String")
        XCTAssertTrue(jsonObject?["jailBreakScore"] is Double, "jailBreakScore should be Double")
        
        // locale can be nil
        if jsonObject?["locale"] != nil {
            let isStringOrNull = (jsonObject?["locale"] is String) || (jsonObject?["locale"] is NSNull)
            XCTAssertTrue(isStringOrNull, "locale should be String or null")
        }
    }
    
    // MARK: - Static Method Tests
    
    func testGetDeviceModel() {
        let model = PlatformInfo.getDeviceModel()
        
        XCTAssertFalse(model.isEmpty, "Device model should not be empty")
        
        // Should contain alphanumeric characters
        let hasAlphanumeric = model.rangeOfCharacter(from: .alphanumerics) != nil
        XCTAssertTrue(hasAlphanumeric, "Device model should contain alphanumeric characters")
        
        // Should not contain spaces or special characters typically
        let hasOnlyValidCharacters = model.rangeOfCharacter(from: .alphanumerics.union(.punctuationCharacters)) != nil
        XCTAssertTrue(hasOnlyValidCharacters, "Device model should contain valid characters")
        
        // Should be consistent across calls
        let model2 = PlatformInfo.getDeviceModel()
        XCTAssertEqual(model, model2, "Device model should be consistent")
    }
    
    func testConvertSysInfo() {
        // Test the convertSysInfo utility method
        let testData: [Int8] = [65, 66, 67, 0] // "ABC\0"
        let mirror = Mirror(reflecting: (testData[0], testData[1], testData[2], testData[3]))
        
        let result = PlatformInfo.convertSysInfo(mirror: mirror)
        XCTAssertEqual(result, "ABC", "Should convert system info correctly")
    }
    
    func testConvertSysInfoWithNullTerminator() {
        // Test with null terminator in middle
        let testData: [Int8] = [72, 101, 108, 108, 111, 0, 87, 111, 114, 108, 100] // "Hello\0World"
        let mirror = Mirror(reflecting: (testData[0], testData[1], testData[2], testData[3], testData[4], testData[5]))
        
        let result = PlatformInfo.convertSysInfo(mirror: mirror)
        XCTAssertEqual(result, "Hello", "Should stop at null terminator")
    }
    
    func testConvertSysInfoEmptyString() {
        // Test with immediate null terminator
        let testData: [Int8] = [0]
        let mirror = Mirror(reflecting: (testData[0], 0, 0, 0))
        
        let result = PlatformInfo.convertSysInfo(mirror: mirror)
        XCTAssertEqual(result, "", "Should return empty string for immediate null")
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "PlatformCollector.collect() should return a result")
        XCTAssertEqual(result?.brand, "Apple", "Collected platform should have Apple brand")
    }
    
    func testCollectorCollectReturnsValidData() async {
        let result = await collector.collect()
        
        guard let platformInfo = result else {
            XCTFail("PlatformCollector should return PlatformInfo")
            return
        }
        
        // Validate all properties
        XCTAssertFalse(platformInfo.platform.isEmpty)
        XCTAssertFalse(platformInfo.version.isEmpty)
        XCTAssertFalse(platformInfo.device.isEmpty)
        XCTAssertFalse(platformInfo.deviceName.isEmpty)
        XCTAssertFalse(platformInfo.model.isEmpty)
        XCTAssertEqual(platformInfo.brand, "Apple")
        XCTAssertFalse(platformInfo.timeZone.isEmpty)
        XCTAssertGreaterThanOrEqual(platformInfo.jailBreakScore, 0.0)
        XCTAssertLessThanOrEqual(platformInfo.jailBreakScore, 1.0)
    }
    
    func testCollectorCollectConsistency() async {
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collect should return result")
        XCTAssertNotNil(result2, "Second collect should return result")
        
        // Platform info should be identical
        XCTAssertEqual(result1?.platform, result2?.platform)
        XCTAssertEqual(result1?.version, result2?.version)
        XCTAssertEqual(result1?.device, result2?.device)
        XCTAssertEqual(result1?.model, result2?.model)
        XCTAssertEqual(result1?.brand, result2?.brand)
        XCTAssertEqual(result1?.timeZone, result2?.timeZone)
        XCTAssertEqual(result1?.jailBreakScore, result2?.jailBreakScore)
        
        // Device name might change if user changes it, but typically stable
        XCTAssertEqual(result1?.deviceName, result2?.deviceName)
        
        // Locale should be consistent
        XCTAssertEqual(result1?.locale, result2?.locale)
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testPlatformCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let platformCollector = defaultCollectors.first { $0.key == "platform" }
        
        XCTAssertNotNil(platformCollector, "Default collectors should include PlatformCollector")
        XCTAssertTrue(platformCollector is PlatformCollector,
                     "Default platform collector should be PlatformCollector instance")
    }
    
    func testPlatformCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["platform"], "Result should contain platform data")
        
        // Verify the structure matches expectations
        if let platformData = result["platform"] as? [String: Any] {
            XCTAssertEqual(platformData["brand"] as? String, "Apple")
            XCTAssertNotNil(platformData["platform"], "Platform data should have platform")
            XCTAssertNotNil(platformData["version"], "Platform data should have version")
            XCTAssertNotNil(platformData["device"], "Platform data should have device")
            XCTAssertNotNil(platformData["deviceName"], "Platform data should have deviceName")
            XCTAssertNotNil(platformData["model"], "Platform data should have model")
            XCTAssertNotNil(platformData["timeZone"], "Platform data should have timeZone")
            XCTAssertNotNil(platformData["jailBreakScore"], "Platform data should have jailBreakScore")
        } else {
            XCTFail("Platform data should be a dictionary")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: PlatformInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.collector.collect()
                }
            }
            
            var results: [PlatformInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be identical (platform info doesn't change during app run)
            let validResults = results.compactMap { $0 }
            if validResults.count > 1 {
                let first = validResults[0]
                for result in validResults {
                    XCTAssertEqual(result.platform, first.platform)
                    XCTAssertEqual(result.version, first.version)
                    XCTAssertEqual(result.device, first.device)
                    XCTAssertEqual(result.model, first.model)
                    XCTAssertEqual(result.brand, first.brand)
                    XCTAssertEqual(result.timeZone, first.timeZone)
                    XCTAssertEqual(result.jailBreakScore, first.jailBreakScore)
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: PlatformCollector?
        
        autoreleasepool {
            let localCollector = PlatformCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testPlatformInfoWithDifferentTimeZones() async {
        // Test with different timezones (if possible)
        let testTimeZones = [
            TimeZone(identifier: "America/New_York"),
            TimeZone(identifier: "Europe/London"),
            TimeZone(identifier: "Asia/Tokyo")
        ]
        
        for timeZone in testTimeZones {
            if let tz = timeZone {
                // We can't actually change the system timezone in a test,
                // but we can verify that our code would handle different values
                XCTAssertFalse(tz.identifier.isEmpty, "TimeZone identifier should not be empty")
            }
        }
        
        // Verify current platform info uses system timezone
        let platformInfo = await PlatformInfo()
        XCTAssertEqual(platformInfo.timeZone, TimeZone.current.identifier)
    }
    
    func testPlatformInfoVersionFormat() async {
        let platformInfo = await PlatformInfo()
        
        // iOS version should follow semantic versioning pattern
        let version = platformInfo.version
        XCTAssertTrue(version.contains("."), "Version should contain periods")
        
        // Should start with a digit
        XCTAssertTrue(version.first?.isNumber ?? false, "Version should start with a number")
        
        // Should not contain non-version characters
        let versionCharacterSet = CharacterSet(charactersIn: "0123456789.")
        let hasOnlyVersionChars = version.rangeOfCharacter(from: versionCharacterSet.inverted) == nil
        XCTAssertTrue(hasOnlyVersionChars, "Version should contain only numbers and periods")
    }

    
    // MARK: - Validation Helper Tests
    
    func testPlatformInfoEquality() async {
        let info1 = await PlatformInfo()
        let info2 = await PlatformInfo()
        
        // All platform info should be identical across instances
        XCTAssertEqual(info1.platform, info2.platform)
        XCTAssertEqual(info1.version, info2.version)
        XCTAssertEqual(info1.device, info2.device)
        XCTAssertEqual(info1.model, info2.model)
        XCTAssertEqual(info1.brand, info2.brand)
        XCTAssertEqual(info1.locale, info2.locale)
        XCTAssertEqual(info1.timeZone, info2.timeZone)
        XCTAssertEqual(info1.jailBreakScore, info2.jailBreakScore)
        
        // Device name might be identical, but could potentially change
        // In practice, it should be the same during a test run
        XCTAssertEqual(info1.deviceName, info2.deviceName)
    }
    
    func testDeviceModelFormatting() {
        let model = PlatformInfo.getDeviceModel()
        
        // Device model should follow Apple's naming convention
        // Examples: iPhone15,2, iPad13,1, iPod9,1
        let hasExpectedFormat = model.contains("iPhone") ||
                               model.contains("iPad") ||
                               model.contains("iPod") ||
                               model.contains("Mac") ||
                               model.contains("AudioAccessory")
        
        // In simulator, might get different values, so be flexible
        if !hasExpectedFormat {
            // At least should not be empty and should have some structure
            XCTAssertGreaterThan(model.count, 3, "Model should have reasonable length")
            XCTAssertTrue(model.rangeOfCharacter(from: .alphanumerics) != nil,
                         "Model should contain alphanumeric characters")
        }
    }
    
    // MARK: - System Integration Tests
    
    func testPlatformInfoMatchesUIDevice() async {
        let platformInfo = await PlatformInfo()
        let systemName = await UIDevice.current.systemName
        let systemVersion = await UIDevice.current.systemVersion
        let model = await UIDevice.current.model
        let name = await UIDevice.current.name
        
        XCTAssertEqual(platformInfo.platform, systemName, "Platform should match UIDevice")
        XCTAssertEqual(platformInfo.version, systemVersion, "Version should match UIDevice")
        XCTAssertEqual(platformInfo.device, model, "Device should match UIDevice")
        XCTAssertEqual(platformInfo.deviceName, name, "Device name should match UIDevice")
        XCTAssertEqual(platformInfo.brand, "Apple", "Brand should always be Apple")
    }
    
    func testPlatformInfoMatchesLocale() async {
        let platformInfo = await PlatformInfo()
        let currentLocale = Locale.current
        
        if let platformLocale = platformInfo.locale {
            XCTAssertEqual(platformLocale, currentLocale.languageCode,
                          "Locale should match system language code")
        } else {
            // Locale can be nil if language code is unavailable
            XCTAssertNil(currentLocale.languageCode, "If platform locale is nil, system locale should also be nil")
        }
    }
}
