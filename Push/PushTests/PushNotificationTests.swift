//
//  PushNotificationTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushNotificationTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func testInitializationWithMinimalParameters() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        
        XCTAssertFalse(notification.id.isEmpty)
        XCTAssertEqual(notification.credentialId, "credential-123")
        XCTAssertEqual(notification.ttl, 120)
        XCTAssertEqual(notification.messageId, "msg-456")
        XCTAssertNil(notification.messageText)
        XCTAssertNil(notification.customPayload)
        XCTAssertNil(notification.challenge)
        XCTAssertNil(notification.numbersChallenge)
        XCTAssertNil(notification.loadBalancer)
        XCTAssertNil(notification.contextInfo)
        XCTAssertEqual(notification.pushType, .default)
        XCTAssertNotNil(notification.createdAt)
        XCTAssertNil(notification.sentAt)
        XCTAssertNil(notification.respondedAt)
        XCTAssertFalse(notification.approved)
        XCTAssertTrue(notification.pending)
        XCTAssertNil(notification.additionalData)
    }
    
    func testInitializationWithAllParameters() {
        let id = "notification-123"
        let createdAt = Date(timeIntervalSince1970: 1609459200)
        let sentAt = Date(timeIntervalSince1970: 1609459210)
        let respondedAt = Date(timeIntervalSince1970: 1609459220)
        let additionalData: [String: Any] = ["key": "value", "number": 42]
        
        let notification = PushNotification(
            id: id,
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            messageText: "Login attempt from Chrome",
            customPayload: "{\"custom\":\"data\"}",
            challenge: "verify123",
            numbersChallenge: "12, 34, 56",
            loadBalancer: "lb-cookie",
            contextInfo: "{\"ip\":\"192.168.1.1\"}",
            pushType: .challenge,
            createdAt: createdAt,
            sentAt: sentAt,
            respondedAt: respondedAt,
            additionalData: additionalData,
            approved: true,
            pending: false
        )
        
        XCTAssertEqual(notification.id, id)
        XCTAssertEqual(notification.credentialId, "credential-123")
        XCTAssertEqual(notification.ttl, 120)
        XCTAssertEqual(notification.messageId, "msg-456")
        XCTAssertEqual(notification.messageText, "Login attempt from Chrome")
        XCTAssertEqual(notification.customPayload, "{\"custom\":\"data\"}")
        XCTAssertEqual(notification.challenge, "verify123")
        XCTAssertEqual(notification.numbersChallenge, "12, 34, 56")
        XCTAssertEqual(notification.loadBalancer, "lb-cookie")
        XCTAssertEqual(notification.contextInfo, "{\"ip\":\"192.168.1.1\"}")
        XCTAssertEqual(notification.pushType, .challenge)
        XCTAssertEqual(notification.createdAt, createdAt)
        XCTAssertEqual(notification.sentAt, sentAt)
        XCTAssertEqual(notification.respondedAt, respondedAt)
        XCTAssertTrue(notification.approved)
        XCTAssertFalse(notification.pending)
        XCTAssertNotNil(notification.additionalData)
    }
    
    // MARK: - Computed Properties Tests
    
    func testTypeProperty() {
        let defaultNotification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        XCTAssertEqual(defaultNotification.type, "default")
        
        let challengeNotification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .challenge
        )
        XCTAssertEqual(challengeNotification.type, "challenge")
        
        let biometricNotification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .biometric
        )
        XCTAssertEqual(biometricNotification.type, "biometric")
    }
    
    func testRespondedProperty() {
        // Approved notification
        var notification1 = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default,
            approved: true,
            pending: false
        )
        XCTAssertTrue(notification1.responded)
        
        // Denied notification
        notification1.approved = false
        notification1.pending = false
        XCTAssertTrue(notification1.responded)
        
        // Pending notification
        let notification2 = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default,
            approved: false,
            pending: true
        )
        XCTAssertFalse(notification2.responded)
    }
    
    func testIsExpiredProperty() {
        // Not expired (just created with 120s TTL)
        let notification1 = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        XCTAssertFalse(notification1.isExpired)
        
        // Expired (created 2 minutes ago with 60s TTL)
        let notification2 = PushNotification(
            credentialId: "credential-123",
            ttl: 60,
            messageId: "msg-456",
            pushType: .default,
            createdAt: Date(timeIntervalSinceNow: -120)
        )
        XCTAssertTrue(notification2.isExpired)
        
        // Edge case: exactly at TTL boundary
        let notification3 = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default,
            createdAt: Date(timeIntervalSinceNow: -120)
        )
        // Should be expired (elapsed time >= TTL)
        XCTAssertTrue(notification3.isExpired)
    }
    
    // MARK: - Action Methods Tests
    
    func testMarkApproved() {
        var notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        
        XCTAssertFalse(notification.approved)
        XCTAssertTrue(notification.pending)
        XCTAssertNil(notification.respondedAt)
        
        notification.markApproved()
        
        XCTAssertTrue(notification.approved)
        XCTAssertFalse(notification.pending)
        XCTAssertNotNil(notification.respondedAt)
    }
    
    func testMarkDenied() {
        var notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        
        XCTAssertFalse(notification.approved)
        XCTAssertTrue(notification.pending)
        XCTAssertNil(notification.respondedAt)
        
        notification.markDenied()
        
        XCTAssertFalse(notification.approved)
        XCTAssertFalse(notification.pending)
        XCTAssertNotNil(notification.respondedAt)
    }
    
    func testGetNumbersChallengeWithValidInput() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: "12, 34, 56",
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertEqual(numbers.count, 3)
        XCTAssertEqual(numbers[0], 12)
        XCTAssertEqual(numbers[1], 34)
        XCTAssertEqual(numbers[2], 56)
    }
    
    func testGetNumbersChallengeWithoutSpaces() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: "12,34,56",
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertEqual(numbers.count, 3)
        XCTAssertEqual(numbers, [12, 34, 56])
    }
    
    func testGetNumbersChallengeWithExtraSpaces() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: "  12  ,  34  ,  56  ",
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertEqual(numbers, [12, 34, 56])
    }
    
    func testGetNumbersChallengeWithNil() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: nil,
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertTrue(numbers.isEmpty)
    }
    
    func testGetNumbersChallengeWithInvalidData() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: "abc, def, ghi",
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertTrue(numbers.isEmpty)
    }
    
    func testGetNumbersChallengeWithMixedData() {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            numbersChallenge: "12, abc, 34, def, 56",
            pushType: .challenge
        )
        
        let numbers = notification.getNumbersChallenge()
        XCTAssertEqual(numbers, [12, 34, 56])
    }
    
    // MARK: - Encoding Tests
    
    func testEncoding() throws {
        let notification = PushNotification(
            id: "notification-123",
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            messageText: "Login attempt",
            pushType: .default,
            createdAt: Date(timeIntervalSince1970: 1609459200),
            approved: false,
            pending: true
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notification)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["id"] as? String, "notification-123")
        XCTAssertEqual(json?["credentialId"] as? String, "credential-123")
        XCTAssertEqual(json?["ttl"] as? Int, 120)
        XCTAssertEqual(json?["messageId"] as? String, "msg-456")
        XCTAssertEqual(json?["approved"] as? Bool, false)
        XCTAssertEqual(json?["pending"] as? Bool, true)
    }
    
    // MARK: - Decoding Tests
    
    func testDecoding() throws {
        let json = """
        {
            "id": "notification-123",
            "credentialId": "credential-123",
            "ttl": 120,
            "messageId": "msg-456",
            "messageText": "Login attempt",
            "customPayload": null,
            "challenge": null,
            "numbersChallenge": "12, 34, 56",
            "loadBalancer": null,
            "contextInfo": null,
            "pushType": "challenge",
            "createdAt": 1609459200,
            "sentAt": null,
            "respondedAt": null,
            "approved": false,
            "pending": true
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let notification = try decoder.decode(PushNotification.self, from: data)
        
        XCTAssertEqual(notification.id, "notification-123")
        XCTAssertEqual(notification.credentialId, "credential-123")
        XCTAssertEqual(notification.ttl, 120)
        XCTAssertEqual(notification.messageId, "msg-456")
        XCTAssertEqual(notification.messageText, "Login attempt")
        XCTAssertEqual(notification.numbersChallenge, "12, 34, 56")
        XCTAssertEqual(notification.pushType, .challenge)
        XCTAssertFalse(notification.approved)
        XCTAssertTrue(notification.pending)
    }
    
    func testRoundTripEncoding() throws {
        let original = PushNotification(
            id: "notification-123",
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            messageText: "Login attempt",
            numbersChallenge: "12, 34, 56",
            pushType: .challenge,
            approved: false,
            pending: true
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PushNotification.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.credentialId, original.credentialId)
        XCTAssertEqual(decoded.ttl, original.ttl)
        XCTAssertEqual(decoded.messageId, original.messageId)
        XCTAssertEqual(decoded.messageText, original.messageText)
        XCTAssertEqual(decoded.numbersChallenge, original.numbersChallenge)
        XCTAssertEqual(decoded.pushType, original.pushType)
        XCTAssertEqual(decoded.approved, original.approved)
        XCTAssertEqual(decoded.pending, original.pending)
    }
    
    // MARK: - CustomStringConvertible Tests
    
    func testDescription() {
        let notification = PushNotification(
            id: "notification-123",
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default,
            approved: false,
            pending: true
        )
        
        let description = notification.description
        XCTAssertTrue(description.contains("notification-123"))
        XCTAssertTrue(description.contains("default"))
        XCTAssertTrue(description.contains("false")) // approved
        XCTAssertTrue(description.contains("true")) // pending
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        let notification = PushNotification(
            credentialId: "credential-123",
            ttl: 120,
            messageId: "msg-456",
            pushType: .default
        )
        
        await Task {
            XCTAssertEqual(notification.credentialId, "credential-123")
        }.value
    }
}
