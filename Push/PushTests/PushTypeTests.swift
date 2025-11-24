//
//  PushTypeTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushTypeTests: XCTestCase {
    
    // MARK: - Basic Enum Tests
    
    func testAllCases() {
        let allTypes = PushType.allCases
        XCTAssertEqual(allTypes.count, 3)
        XCTAssertTrue(allTypes.contains(.default))
        XCTAssertTrue(allTypes.contains(.challenge))
        XCTAssertTrue(allTypes.contains(.biometric))
    }
    
    func testRawValues() {
        XCTAssertEqual(PushType.default.rawValue, "default")
        XCTAssertEqual(PushType.challenge.rawValue, "challenge")
        XCTAssertEqual(PushType.biometric.rawValue, "biometric")
    }
    
    // MARK: - Encoding Tests
    
    func testEncoding() throws {
        let encoder = JSONEncoder()
        
        let defaultData = try encoder.encode(PushType.default)
        let defaultString = String(data: defaultData, encoding: .utf8)
        XCTAssertEqual(defaultString, "\"default\"")
        
        let challengeData = try encoder.encode(PushType.challenge)
        let challengeString = String(data: challengeData, encoding: .utf8)
        XCTAssertEqual(challengeString, "\"challenge\"")
        
        let biometricData = try encoder.encode(PushType.biometric)
        let biometricString = String(data: biometricData, encoding: .utf8)
        XCTAssertEqual(biometricString, "\"biometric\"")
    }
    
    // MARK: - Decoding Tests
    
    func testDecoding() throws {
        let decoder = JSONDecoder()
        
        let defaultData = "\"default\"".data(using: .utf8)!
        let defaultType = try decoder.decode(PushType.self, from: defaultData)
        XCTAssertEqual(defaultType, .default)
        
        let challengeData = "\"challenge\"".data(using: .utf8)!
        let challengeType = try decoder.decode(PushType.self, from: challengeData)
        XCTAssertEqual(challengeType, .challenge)
        
        let biometricData = "\"biometric\"".data(using: .utf8)!
        let biometricType = try decoder.decode(PushType.self, from: biometricData)
        XCTAssertEqual(biometricType, .biometric)
    }
    
    func testDecodingInvalidValue() {
        let decoder = JSONDecoder()
        let invalidData = "\"invalid\"".data(using: .utf8)!
        
        XCTAssertThrowsError(try decoder.decode(PushType.self, from: invalidData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - fromString Tests
    
    func testFromStringDefault() throws {
        XCTAssertEqual(try PushType.fromString("default"), .default)
        XCTAssertEqual(try PushType.fromString("DEFAULT"), .default)
        XCTAssertEqual(try PushType.fromString("Default"), .default)
    }
    
    func testFromStringChallenge() throws {
        XCTAssertEqual(try PushType.fromString("challenge"), .challenge)
        XCTAssertEqual(try PushType.fromString("CHALLENGE"), .challenge)
        XCTAssertEqual(try PushType.fromString("Challenge"), .challenge)
    }
    
    func testFromStringBiometric() throws {
        XCTAssertEqual(try PushType.fromString("biometric"), .biometric)
        XCTAssertEqual(try PushType.fromString("BIOMETRIC"), .biometric)
        XCTAssertEqual(try PushType.fromString("Biometric"), .biometric)
    }
    
    func testFromStringInvalid() {
        XCTAssertThrowsError(try PushType.fromString("invalid")) { error in
            guard let pushError = error as? PushError else {
                XCTFail("Expected PushError")
                return
            }
            
            if case .invalidPushType(let type) = pushError {
                XCTAssertEqual(type, "invalid")
            } else {
                XCTFail("Expected invalidPushType error")
            }
        }
        
        XCTAssertThrowsError(try PushType.fromString(""))
        XCTAssertThrowsError(try PushType.fromString("totp"))
        XCTAssertThrowsError(try PushType.fromString("push"))
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        // Test that PushType can be safely used across actor boundaries
        let type: PushType = .default
        
        await Task {
            XCTAssertEqual(type, .default)
        }.value
    }
}
