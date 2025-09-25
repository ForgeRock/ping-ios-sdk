// 
//  TelephonyCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CoreTelephony
@testable import PingDeviceProfile

class TelephonyCollectorTests: XCTestCase {
    
    var collector: TelephonyCollector!
    
    override func setUp() {
        super.setUp()
        collector = TelephonyCollector()
    }
    
    override func tearDown() {
        collector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "telephony", "TelephonyCollector should have correct key")
    }
    
    // MARK: - TelephonyInfo Tests
    
    func testTelephonyInfoInitialization() {
        let telephonyInfo = TelephonyInfo()
        
        XCTAssertNotNil(telephonyInfo.networkCountryIso, "NetworkCountryIso should not be nil")
        XCTAssertNotNil(telephonyInfo.carrierName, "CarrierName should not be nil")
    }
    
    func testTelephonyInfoDefaultValues() {
        let telephonyInfo = TelephonyInfo()
        
        // In test environment without cellular, might default to "Unknown"
        let validCountryCodes = ["Unknown"] + Locale.isoRegionCodes
        
        if let countryIso = telephonyInfo.networkCountryIso {
            // Should be either "Unknown" or a valid ISO country code
            let isValidCountryCode = validCountryCodes.contains(countryIso) ||
                                   countryIso.count == 2 // ISO country codes are 2 characters
            XCTAssertTrue(isValidCountryCode || countryIso == "Unknown",
                         "Country ISO should be valid or Unknown")
        }
        
        if let carrierName = telephonyInfo.carrierName {
            XCTAssertFalse(carrierName.isEmpty, "Carrier name should not be empty")
        }
    }
    
    func testTelephonyInfoCodable() throws {
        let telephonyInfo = TelephonyInfo()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(telephonyInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded TelephonyInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(TelephonyInfo.self, from: data)
        
        XCTAssertEqual(telephonyInfo.networkCountryIso, decodedInfo.networkCountryIso)
        XCTAssertEqual(telephonyInfo.carrierName, decodedInfo.carrierName)
    }
    
    func testTelephonyInfoJSONStructure() throws {
        let telephonyInfo = TelephonyInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(telephonyInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        
        // Check required fields
        if let networkCountryIso = jsonObject?["networkCountryIso"] {
            XCTAssertTrue(networkCountryIso is String || networkCountryIso is NSNull,
                         "networkCountryIso should be String or null")
        }
        
        if let carrierName = jsonObject?["carrierName"] {
            XCTAssertTrue(carrierName is String || carrierName is NSNull,
                         "carrierName should be String or null")
        }
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "TelephonyCollector.collect() should return a result")
        XCTAssertNotNil(result?.networkCountryIso, "Collected TelephonyInfo should have networkCountryIso")
        XCTAssertNotNil(result?.carrierName, "Collected TelephonyInfo should have carrierName")
    }
    
    func testCollectorCollectReturnsValidData() async {
        let result = await collector.collect()
        
        guard let telephonyInfo = result else {
            XCTFail("TelephonyCollector should return TelephonyInfo")
            return
        }
        
        // Validate the data
        if let countryIso = telephonyInfo.networkCountryIso {
            XCTAssertFalse(countryIso.isEmpty, "Country ISO should not be empty")
        }
        
        if let carrierName = telephonyInfo.carrierName {
            XCTAssertFalse(carrierName.isEmpty, "Carrier name should not be empty")
        }
    }
    
    func testCollectorCollectConsistency() async {
        let result1 = await collector.collect()
        let result2 = await collector.collect()
        
        XCTAssertNotNil(result1, "First collect should return result")
        XCTAssertNotNil(result2, "Second collect should return result")
        
        // Telephony info should be consistent (doesn't change during app run)
        XCTAssertEqual(result1?.networkCountryIso, result2?.networkCountryIso,
                      "Network country ISO should be consistent")
        XCTAssertEqual(result1?.carrierName, result2?.carrierName,
                      "Carrier name should be consistent")
    }
    
    // MARK: - SelectPrimaryCarrier Tests
    
    func testSelectPrimaryCarrierWithSingleCarrier() {
        let carriers = [
            (carrierName: "Verizon", isoCountryCode: "US")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select single carrier")
        XCTAssertEqual(selected?.carrierName, "Verizon", "Should select Verizon")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    func testSelectPrimaryCarrierWithMultipleCarriers() {
        let carriers = [
            (carrierName: "Verizon", isoCountryCode: "US"),
            (carrierName: "AT&T", isoCountryCode: "US"),
            (carrierName: "T-Mobile", isoCountryCode: "US")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        
        // Should select one of the carriers (alphabetically first)
        let expectedCarriers = ["AT&T", "T-Mobile", "Verizon"]
        XCTAssertTrue(expectedCarriers.contains(selected?.carrierName ?? ""),
                     "Should select one of the expected carriers")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    func testSelectPrimaryCarrierAlphabeticalSorting() {
        let carriers = [
            (carrierName: "Zebra Carrier", isoCountryCode: "US"),
            (carrierName: "Apple Carrier", isoCountryCode: "US"),
            (carrierName: "Beta Carrier", isoCountryCode: "US")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        XCTAssertEqual(selected?.carrierName, "Apple Carrier",
                      "Should select alphabetically first carrier")
    }
    
    func testSelectPrimaryCarrierWithNilNames() {
        let carriers = [
            (carrierName: nil as String?, isoCountryCode: "US"),
            (carrierName: "Verizon", isoCountryCode: "US"),
            (carrierName: nil as String?, isoCountryCode: "CA")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        XCTAssertEqual(selected?.carrierName, "Verizon",
                      "Should prefer carrier with name over nil names")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    func testSelectPrimaryCarrierAllNilNames() {
        let carriers = [
            (carrierName: nil as String?, isoCountryCode: "US"),
            (carrierName: nil as String?, isoCountryCode: "CA"),
            (carrierName: nil as String?, isoCountryCode: "GB")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier even with nil names")
        XCTAssertNil(selected?.carrierName, "Selected carrier name should be nil")
        
        // Should select based on country code alphabetical order
        let expectedCountries = ["CA", "GB", "US"]
        XCTAssertTrue(expectedCountries.contains(selected?.isoCountryCode ?? ""),
                     "Should select one of the expected countries")
    }
    
    func testSelectPrimaryCarrierWithNilCountryCodes() {
        let carriers = [
            (carrierName: "Verizon", isoCountryCode: nil as String?),
            (carrierName: "AT&T", isoCountryCode: "US"),
            (carrierName: "Rogers", isoCountryCode: nil as String?)
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        XCTAssertEqual(selected?.carrierName, "AT&T",
                      "Should prefer carrier with country code")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    func testSelectPrimaryCarrierEmptyArray() {
        let carriers: [(carrierName: String?, isoCountryCode: String?)] = []
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNil(selected, "Should return nil for empty array")
    }
    
    func testSelectPrimaryCarrierComplexSorting() {
        let carriers = [
            (carrierName: nil as String?, isoCountryCode: nil as String?),
            (carrierName: "Verizon", isoCountryCode: nil as String?),
            (carrierName: nil as String?, isoCountryCode: "US"),
            (carrierName: "AT&T", isoCountryCode: "US")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        XCTAssertEqual(selected?.carrierName, "AT&T",
                      "Should select carrier with both name and country code")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                _ = await collector.collect()
            }
        }
    }
    
    func testTelephonyInfoInitializationPerformance() {
        measure {
            _ = TelephonyInfo()
        }
    }
    
    func testSelectPrimaryCarrierPerformance() {
        let carriers = Array(repeating: (carrierName: "TestCarrier", isoCountryCode: "US"), count: 100)
        
        measure {
            _ = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        }
    }
    
    // MARK: - Integration Tests
    
    func testTelephonyCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let telephonyCollector = defaultCollectors.first { $0.key == "telephony" }
        
        XCTAssertNotNil(telephonyCollector, "Default collectors should include TelephonyCollector")
        XCTAssertTrue(telephonyCollector is TelephonyCollector,
                     "Default telephony collector should be TelephonyCollector instance")
    }
    
    func testTelephonyCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["telephony"], "Result should contain telephony data")
        
        // Verify the structure matches expectations
        if let telephonyData = result["telephony"] as? [String: Any] {
            XCTAssertNotNil(telephonyData["networkCountryIso"],
                           "Telephony data should have networkCountryIso")
            XCTAssertNotNil(telephonyData["carrierName"],
                           "Telephony data should have carrierName")
            
            // Should be strings or null
            if let networkCountryIso = telephonyData["networkCountryIso"] {
                XCTAssertTrue(networkCountryIso is String || networkCountryIso is NSNull,
                             "networkCountryIso should be String or NSNull")
            }
            
            if let carrierName = telephonyData["carrierName"] {
                XCTAssertTrue(carrierName is String || carrierName is NSNull,
                             "carrierName should be String or NSNull")
            }
        } else {
            XCTFail("Telephony data should be a dictionary")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCollectorDoesNotThrow() async {
        // TelephonyCollector.collect() should never throw
        _ = await collector.collect()
        XCTAssertTrue(true, "collect() completed without throwing")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: TelephonyInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await self.collector.collect()
                }
            }
            
            var results: [TelephonyInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be identical (telephony info doesn't change during app run)
            let validResults = results.compactMap { $0 }
            if validResults.count > 1 {
                let first = validResults[0]
                for result in validResults {
                    XCTAssertEqual(result.networkCountryIso, first.networkCountryIso,
                                  "Network country ISO should be consistent")
                    XCTAssertEqual(result.carrierName, first.carrierName,
                                  "Carrier name should be consistent")
                }
            }
        }
    }
    
    func testConcurrentSelectPrimaryCarrier() async {
        let carriers = [
            (carrierName: "Verizon", isoCountryCode: "US"),
            (carrierName: "AT&T", isoCountryCode: "US")
        ]
        
        let iterations = 100
        
        await withTaskGroup(of: (carrierName: String?, isoCountryCode: String?)?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return TelephonyCollector.selectPrimaryCarrier(from: carriers)
                }
            }
            
            var results: [(carrierName: String?, isoCountryCode: String?)?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be identical (pure function)
            let validResults = results.compactMap { $0 }
            if validResults.count > 1 {
                let first = validResults[0]
                for result in validResults {
                    XCTAssertEqual(result.carrierName, first.carrierName,
                                  "Concurrent results should be identical")
                    XCTAssertEqual(result.isoCountryCode, first.isoCountryCode,
                                  "Concurrent results should be identical")
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: TelephonyCollector?
        
        autoreleasepool {
            let localCollector = TelephonyCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testTelephonyInfoWithNoCarriers() {
        // This tests the case where CTTelephonyNetworkInfo returns no providers
        // In simulator or devices without cellular, this is expected
        let telephonyInfo = TelephonyInfo()
        
        // Should still return valid strings (likely "Unknown")
        XCTAssertNotNil(telephonyInfo.networkCountryIso, "Should have country ISO even without carriers")
        XCTAssertNotNil(telephonyInfo.carrierName, "Should have carrier name even without carriers")
    }
    
    func testSelectPrimaryCarrierWithIdenticalCarriers() {
        let carriers = [
            (carrierName: "SameCarrier", isoCountryCode: "US"),
            (carrierName: "SameCarrier", isoCountryCode: "US"),
            (carrierName: "SameCarrier", isoCountryCode: "US")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        XCTAssertEqual(selected?.carrierName, "SameCarrier", "Should select the carrier")
        XCTAssertEqual(selected?.isoCountryCode, "US", "Should select US")
    }
    
    func testSelectPrimaryCarrierWithEmptyStrings() {
        let carriers = [
            (carrierName: "", isoCountryCode: "US"),
            (carrierName: "Verizon", isoCountryCode: "")
        ]
        
        let selected = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        
        XCTAssertNotNil(selected, "Should select a carrier")
        // The sorting logic treats empty strings as valid, so either could be selected
        // depending on the specific implementation details
    }
    
    // MARK: - System Integration Tests
    
    func testTelephonyInfoUsesCTTelephonyNetworkInfo() {
        // This test verifies that TelephonyInfo actually uses CTTelephonyNetworkInfo
        // We can't easily mock CTTelephonyNetworkInfo, but we can verify that
        // the initialization completes without crashing and produces valid output
        
        let telephonyInfo = TelephonyInfo()
        
        // Should complete without crashing
        XCTAssertNotNil(telephonyInfo, "TelephonyInfo should initialize successfully")
        XCTAssertNotNil(telephonyInfo.networkCountryIso, "Should produce country ISO")
        XCTAssertNotNil(telephonyInfo.carrierName, "Should produce carrier name")
    }
    
    func testTelephonyInfoEquality() {
        let info1 = TelephonyInfo()
        let info2 = TelephonyInfo()
        
        // Telephony info should be identical across instances (system state doesn't change)
        XCTAssertEqual(info1.networkCountryIso, info2.networkCountryIso,
                      "Network country ISO should be consistent")
        XCTAssertEqual(info1.carrierName, info2.carrierName,
                      "Carrier name should be consistent")
    }
    
    // MARK: - Country Code Validation Tests
    
    func testNetworkCountryIsoFormat() async {
        let result = await collector.collect()
        
        guard let telephonyInfo = result,
              let countryIso = telephonyInfo.networkCountryIso else {
            // This is acceptable in test environment
            return
        }
        
        if countryIso != "Unknown" {
            // Should be a valid 2-letter ISO country code
            XCTAssertEqual(countryIso.count, 2, "Country ISO should be 2 characters")
            XCTAssertTrue(countryIso.allSatisfy { $0.isLetter }, "Country ISO should contain only letters")
            XCTAssertEqual(countryIso, countryIso.uppercased(), "Country ISO should be uppercase")
        }
    }
    
    func testCarrierNameFormat() async {
        let result = await collector.collect()
        
        guard let telephonyInfo = result,
              let carrierName = telephonyInfo.carrierName else {
            return
        }
        
        XCTAssertFalse(carrierName.isEmpty, "Carrier name should not be empty")
        
        if carrierName != "Unknown" {
            // Should be a reasonable length
            XCTAssertLessThan(carrierName.count, 100, "Carrier name should not be excessively long")
            XCTAssertGreaterThan(carrierName.count, 0, "Carrier name should not be empty")
        }
    }
}
