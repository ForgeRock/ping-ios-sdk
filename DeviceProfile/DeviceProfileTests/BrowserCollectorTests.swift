// 
//  BrowserCollectorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import WebKit
@testable import PingDeviceProfile

class BrowserCollectorTests: XCTestCase {
    
    var collector: BrowserCollector!
    
    override func setUp() {
        super.setUp()
        collector = BrowserCollector()
    }
    
    override func tearDown() {
        collector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testCollectorKey() {
        XCTAssertEqual(collector.key, "browser", "BrowserCollector should have correct key")
    }
    
    // MARK: - BrowserInfo Tests
    
    func testBrowserInfoInitialization() {
        let testUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        let browserInfo = BrowserInfo(userAgent: testUserAgent)
        
        XCTAssertEqual(browserInfo.userAgent, testUserAgent, "BrowserInfo should store user agent correctly")
    }
    
    func testBrowserInfoCodable() throws {
        let testUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
        let browserInfo = BrowserInfo(userAgent: testUserAgent)
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(browserInfo)
        XCTAssertGreaterThan(data.count, 0, "Encoded BrowserInfo should not be empty")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(BrowserInfo.self, from: data)
        XCTAssertEqual(browserInfo.userAgent, decodedInfo.userAgent, "Decoded BrowserInfo should match original")
    }
    
    func testBrowserInfoJSONStructure() throws {
        let testUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        let browserInfo = BrowserInfo(userAgent: testUserAgent)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(browserInfo)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(jsonObject, "Should produce valid JSON object")
        XCTAssertNotNil(jsonObject?["userAgent"], "JSON should contain 'userAgent' key")
        XCTAssertEqual(jsonObject?["userAgent"] as? String, testUserAgent, "userAgent value should match")
    }
    
    // MARK: - BrowserInfo.create() Tests
    
    func testBrowserInfoCreate() async {
        let result = await BrowserInfo.create()
        
        XCTAssertNotNil(result, "BrowserInfo.create() should return a result")
        
        guard let browserInfo = result else { return }
        
        XCTAssertFalse(browserInfo.userAgent.isEmpty, "User agent should not be empty")
        XCTAssertTrue(browserInfo.userAgent.contains("Mozilla"), "User agent should contain Mozilla")
        
        // Should contain typical iOS user agent elements
        let userAgent = browserInfo.userAgent
        let containsTypicalElements = userAgent.contains("iPhone") ||
                                    userAgent.contains("iPad") ||
                                    userAgent.contains("AppleWebKit") ||
                                    userAgent.contains("Safari")
        
        XCTAssertTrue(containsTypicalElements, "User agent should contain typical iOS/WebKit elements")
    }
    
    func testBrowserInfoCreateConsistency() async {
        let result1 = await BrowserInfo.create()
        let result2 = await BrowserInfo.create()
        
        XCTAssertNotNil(result1, "First create should return result")
        XCTAssertNotNil(result2, "Second create should return result")
        
        // User agents should be consistent within the same app session
        XCTAssertEqual(result1?.userAgent, result2?.userAgent,
                      "Multiple calls to create() should return consistent user agent")
    }
    
    func testBrowserInfoCreateUserAgentFormat() async {
        let result = await BrowserInfo.create()
        
        guard let browserInfo = result else {
            XCTFail("BrowserInfo.create() should return a result")
            return
        }
        
        let userAgent = browserInfo.userAgent
        
        // Should not be a fallback "Unknown" value
        XCTAssertNotEqual(userAgent, "Unknown", "Should not return Unknown fallback")
        
        // Should have reasonable length (user agents are typically 100+ characters)
        XCTAssertGreaterThan(userAgent.count, 20, "User agent should be reasonably long")
        
        // Should not contain obvious placeholder text
        XCTAssertFalse(userAgent.contains("placeholder"), "Should not contain placeholder text")
        XCTAssertFalse(userAgent.contains("test"), "Should not contain test text")
    }
    
    // MARK: - Collection Tests
    
    func testCollectorCollect() async {
        let result = await collector.collect()
        
        XCTAssertNotNil(result, "BrowserCollector.collect() should return a result")
        XCTAssertNotNil(result?.userAgent, "Collected BrowserInfo should have userAgent property")
    }
    
    func testCollectorCollectReturnsValidUserAgent() async {
        let result = await collector.collect()
        
        guard let browserInfo = result else {
            XCTFail("BrowserCollector should return BrowserInfo")
            return
        }
        
        XCTAssertFalse(browserInfo.userAgent.isEmpty, "User agent should not be empty")
        
        // User agent should follow standard format patterns
        let userAgent = browserInfo.userAgent
        
        // Should start with Mozilla (standard for most browsers)
        XCTAssertTrue(userAgent.hasPrefix("Mozilla/"), "User agent should start with Mozilla/")
        
        // Should contain version information
        XCTAssertTrue(userAgent.contains("5.0"), "User agent should contain version info")
        
        // Should contain device/platform information
        let containsPlatformInfo = userAgent.contains("iPhone") ||
                                 userAgent.contains("iPad") ||
                                 userAgent.contains("iPod")
        XCTAssertTrue(containsPlatformInfo, "User agent should contain iOS device information")
    }
    
    // MARK: - Performance Tests
    
    func testCollectorCollectPerformance() {
        measure {
            Task {
                let testCollector = BrowserCollector()
                _ = await testCollector.collect()
            }
        }
    }
    
    func testBrowserInfoCreatePerformance() {
        measure {
            Task {
                _ = await BrowserInfo.create()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testBrowserCollectorInDefaultSet() {
        let defaultCollectors = DefaultDeviceCollector.defaultDeviceCollectors()
        let browserCollector = defaultCollectors.first { $0.key == "browser" }
        
        XCTAssertNotNil(browserCollector, "Default collectors should include BrowserCollector")
        XCTAssertTrue(browserCollector is BrowserCollector,
                     "Default browser collector should be BrowserCollector instance")
    }
    
    func testBrowserCollectorInArrayCollection() async throws {
        let collectors: [any DeviceCollector] = [collector]
        let result = try await collectors.collect()
        
        XCTAssertEqual(result.count, 1, "Should have one collector result")
        XCTAssertNotNil(result["browser"], "Result should contain browser data")
        
        // Verify the structure matches expectations
        if let browserData = result["browser"] as? [String: Any] {
            XCTAssertNotNil(browserData["userAgent"], "Browser data should have 'userAgent' key")
            XCTAssertTrue(browserData["userAgent"] is String, "'userAgent' should be String")
            
            let userAgent = browserData["userAgent"] as? String
            XCTAssertFalse(userAgent?.isEmpty ?? true, "userAgent should not be empty")
        } else {
            XCTFail("Browser data should be a dictionary")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentCollection() async {
        let iterations = 10
        
        await withTaskGroup(of: BrowserInfo?.self) { group in
            let testCollector = BrowserCollector()
            for _ in 0..<iterations {
                group.addTask {
                    return await testCollector.collect()
                }
            }
            
            var results: [BrowserInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should be consistent
            let userAgents = results.compactMap { $0?.userAgent }
            if userAgents.count > 1 {
                let firstUserAgent = userAgents[0]
                XCTAssertTrue(userAgents.allSatisfy { $0 == firstUserAgent },
                             "All concurrent results should be consistent")
            }
        }
    }
    
    func testConcurrentBrowserInfoCreate() async {
        let iterations = 5
        
        await withTaskGroup(of: BrowserInfo?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return await BrowserInfo.create()
                }
            }
            
            var results: [BrowserInfo?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent tasks")
            
            // All results should have the same user agent
            let userAgents = results.compactMap { $0?.userAgent }
            if userAgents.count > 1 {
                let firstUserAgent = userAgents[0]
                XCTAssertTrue(userAgents.allSatisfy { $0 == firstUserAgent },
                             "All concurrent BrowserInfo.create() calls should return same user agent")
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testUserAgentStringValidation() async {
        let result = await collector.collect()
        
        guard let browserInfo = result else {
            XCTFail("Should return browser info")
            return
        }
        
        let userAgent = browserInfo.userAgent
        
        // Should not contain newlines or control characters
        XCTAssertFalse(userAgent.contains("\n"), "User agent should not contain newlines")
        XCTAssertFalse(userAgent.contains("\r"), "User agent should not contain carriage returns")
        XCTAssertFalse(userAgent.contains("\t"), "User agent should not contain tabs")
        
        // Should contain printable ASCII characters primarily
        let nonPrintableCharacters = userAgent.unicodeScalars.filter { !$0.isASCII || $0.value < 32 }
        XCTAssertTrue(nonPrintableCharacters.isEmpty, "User agent should contain only printable characters")
    }
    
    func testUserAgentReasonableLength() async {
        let result = await collector.collect()
        
        guard let browserInfo = result else {
            XCTFail("Should return browser info")
            return
        }
        
        let userAgent = browserInfo.userAgent
        
        // Typical user agents are 100-300 characters
        XCTAssertGreaterThan(userAgent.count, 50, "User agent should be reasonably long")
        XCTAssertLessThan(userAgent.count, 1000, "User agent should not be excessively long")
    }
    
    // MARK: - Memory Management Tests
    
    func testCollectorMemoryManagement() {
        weak var weakCollector: BrowserCollector?
        
        autoreleasepool {
            let localCollector = BrowserCollector()
            weakCollector = localCollector
            XCTAssertNotNil(weakCollector, "Collector should exist")
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakCollector, "Collector should be deallocated")
        }
    }
    
    // MARK: - User Agent Pattern Tests
    
    func testUserAgentContainsExpectedPatterns() async {
        let result = await collector.collect()
        
        guard let browserInfo = result else {
            XCTFail("Should return browser info")
            return
        }
        
        let userAgent = browserInfo.userAgent
        
        // Should match typical iOS user agent pattern
        let expectedPatterns = [
            "Mozilla/5.0",
            "AppleWebKit/",
            "Version/",
            "Mobile/",
            "Safari/"
        ]
        
        var matchedPatterns = 0
        for pattern in expectedPatterns {
            if userAgent.contains(pattern) {
                matchedPatterns += 1
            }
        }
        
        XCTAssertGreaterThan(matchedPatterns, 0, "User agent should contain at least some expected patterns")
        
        // Should contain iOS version information
        let containsIOSVersion = userAgent.contains("CPU iPhone OS") ||
                               userAgent.contains("CPU OS") ||
                               userAgent.contains("like Mac OS X")
        XCTAssertTrue(containsIOSVersion, "User agent should contain iOS version information")
    }
}

