//
//  PushPlatformTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushPlatformTests: XCTestCase {
    
    // MARK: - Basic Enum Tests
    
    func testAllCases() {
        let allPlatforms = PushPlatform.allCases
        XCTAssertEqual(allPlatforms.count, 1)
        XCTAssertTrue(allPlatforms.contains(.pingAM))
    }
    
    func testRawValue() {
        XCTAssertEqual(PushPlatform.pingAM.rawValue, "pingam")
    }
    
    // MARK: - Encoding Tests
    
    func testEncoding() throws {
        let encoder = JSONEncoder()
        
        let pingAMData = try encoder.encode(PushPlatform.pingAM)
        let pingAMString = String(data: pingAMData, encoding: .utf8)
        XCTAssertEqual(pingAMString, "\"pingam\"")
    }
    
    // MARK: - Decoding Tests
    
    func testDecoding() throws {
        let decoder = JSONDecoder()
        
        let pingAMData = "\"pingam\"".data(using: .utf8)!
        let platform = try decoder.decode(PushPlatform.self, from: pingAMData)
        XCTAssertEqual(platform, .pingAM)
    }
    
    func testDecodingInvalidValue() {
        let decoder = JSONDecoder()
        let invalidData = "\"invalid\"".data(using: .utf8)!
        
        XCTAssertThrowsError(try decoder.decode(PushPlatform.self, from: invalidData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - fromString Tests
    
    func testFromStringPingAM() throws {
        // Test various formats
        XCTAssertEqual(try PushPlatform.fromString("pingam"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("PINGAM"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("PingAM"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("ping_am"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("PING_AM"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("ping-am"), .pingAM)
        XCTAssertEqual(try PushPlatform.fromString("PING-AM"), .pingAM)
    }
    
    func testFromStringInvalid() {
        XCTAssertThrowsError(try PushPlatform.fromString("invalid")) { error in
            guard let pushError = error as? PushError else {
                XCTFail("Expected PushError")
                return
            }
            
            if case .invalidPlatform(let platform) = pushError {
                XCTAssertEqual(platform, "invalid")
            } else {
                XCTFail("Expected invalidPlatform error")
            }
        }
        
        XCTAssertThrowsError(try PushPlatform.fromString(""))
        XCTAssertThrowsError(try PushPlatform.fromString("forgerock"))
        XCTAssertThrowsError(try PushPlatform.fromString("google"))
    }
    
    // MARK: - Extensibility Tests
    
    func testExtensibility() {
        // Verify that the platform enum can be extended in the future
        // by checking that we can handle additional platforms
        let currentCount = PushPlatform.allCases.count
        XCTAssertGreaterThanOrEqual(currentCount, 1, "Should have at least one platform")
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        // Test that PushPlatform can be safely used across actor boundaries
        let platform: PushPlatform = .pingAM
        
        await Task {
            XCTAssertEqual(platform, .pingAM)
        }.value
    }
}
