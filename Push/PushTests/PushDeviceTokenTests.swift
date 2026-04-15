//
//  PushDeviceTokenTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushDeviceTokenTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func testInitialization() {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let deviceToken = PushDeviceToken(token: token)
        
        XCTAssertEqual(deviceToken.token, token)
        XCTAssertNotNil(deviceToken.createdAt)
    }
    
    func testInitializationWithCustomDate() {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let customDate = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let deviceToken = PushDeviceToken(token: token, createdAt: customDate)
        
        XCTAssertEqual(deviceToken.token, token)
        XCTAssertEqual(deviceToken.createdAt, customDate)
    }
    
    // MARK: - Identifiable Tests
    
    func testIdentifiable() {
        let id = "unique-device-token-id"
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let deviceToken = PushDeviceToken(id: id, token: token)
        
        XCTAssertEqual(deviceToken.id, id)
    }
    
    // MARK: - Encoding Tests
    
    func testEncoding() throws {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let createdAt = Date(timeIntervalSince1970: 1609459200)
        let deviceToken = PushDeviceToken(token: token, createdAt: createdAt)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(deviceToken)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["token"] as? String, token)
        XCTAssertNotNil(json?["createdAt"])
    }
    
    // MARK: - Decoding Tests
    
    func testDecoding() throws {
        let id = "unique-device-token-id"
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let createdAt = Date(timeIntervalSince1970: 1609459200)
        
        let json = """
        {
            "id": "\(id)",
            "token": "\(token)",
            "createdAt": \(createdAt.timeIntervalSince1970)
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let deviceToken = try decoder.decode(PushDeviceToken.self, from: data)
        
        XCTAssertEqual(deviceToken.id, id)
        XCTAssertEqual(deviceToken.token, token)
        XCTAssertEqual(deviceToken.createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970, accuracy: 0.001)
    }
    
    func testRoundTripEncoding() throws {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let original = PushDeviceToken(token: token)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PushDeviceToken.self, from: data)
        
        XCTAssertEqual(decoded.token, original.token)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 0.001)
    }
    
    // MARK: - Equality Tests
    
    func testEquality() {
        let token1 = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let token2 = "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
        
        let deviceToken1 = PushDeviceToken(token: token1)
        let deviceToken2 = PushDeviceToken(token: token1)
        let deviceToken3 = PushDeviceToken(token: token2)
        
        XCTAssertEqual(deviceToken1, deviceToken2)
        XCTAssertNotEqual(deviceToken1, deviceToken3)
    }
    
    func testEqualityIgnoresDate() {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let date1 = Date(timeIntervalSince1970: 1609459200)
        let date2 = Date(timeIntervalSince1970: 1609459300)
        
        let deviceToken1 = PushDeviceToken(token: token, createdAt: date1)
        let deviceToken2 = PushDeviceToken(token: token, createdAt: date2)
        
        // Equality is based on token only, not timestamp
        XCTAssertEqual(deviceToken1, deviceToken2)
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        let token = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        let deviceToken = PushDeviceToken(token: token)
        
        await Task {
            XCTAssertEqual(deviceToken.token, token)
        }.value
    }
}
