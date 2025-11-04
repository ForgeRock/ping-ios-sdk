//
//  PingAMPushHandlerTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingMfaCommons
import PingOrchestrate
@testable import PingPush

final class PingAMPushHandlerTests: XCTestCase {

    private let base64Secret = "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E="
    private var handler: PingAMPushHandler!
    private var mockResponder: MockResponder!

    override func setUp() async throws {
        try await super.setUp()
        mockResponder = MockResponder()
        handler = PingAMPushHandler(httpClient: HttpClient(), logger: nil, pushResponder: mockResponder)
    }

    override func tearDown() async throws {
        handler = nil
        mockResponder = nil
        handler = nil
        try await super.tearDown()
    }

    func testCanHandleMessageDataWithValidJwt() throws {
        let jwt = try sampleJwt()
        let messageData: [String: Any] = [
            "messageId": "message-123",
            "message": jwt
        ]

        XCTAssertTrue(handler.canHandle(messageData: messageData))
    }

    func testCanHandleRejectsInvalidMessageData() {
        XCTAssertFalse(handler.canHandle(messageData: [:]))
        XCTAssertFalse(handler.canHandle(messageData: ["messageId": "id-only"]))
    }

    func testParseMessageFromMapProducesExpectedFields() throws {
        let jwt = try sampleJwt()
        let messageData: [String: Any] = [
            "messageId": "message-123",
            "message": jwt
        ]

        let parsed = try handler.parseMessage(messageData: messageData)

        XCTAssertEqual(parsed["messageId"] as? String, "message-123")
        XCTAssertEqual(parsed["credentialId"] as? String, "mechanism-id")
        XCTAssertEqual(parsed["challenge"] as? String, challengeBase64)
        XCTAssertEqual(parsed["ttl"] as? Int, 180)
        XCTAssertEqual(parsed["messageText"] as? String, "Approve login?")
        XCTAssertEqual(parsed["numbersChallenge"] as? String, "1,2,3")
        XCTAssertEqual(parsed["contextInfo"] as? String, "context")
        XCTAssertEqual(parsed["pushType"] as? String, "DEFAULT")
        XCTAssertEqual(parsed["userId"] as? String, "user-123")
        XCTAssertEqual(parsed["deviceName"] as? String, "iPhone 16")

        let cookie = parsed["amlbCookie"] as? String
        XCTAssertEqual(cookie, "amlb-cookie-value")

        let additional = parsed["additionalData"] as? [String: Any]
        XCTAssertEqual(additional?["extraField"] as? String, "extraValue")
    }

    func testParseMessageFromJwtStringGeneratesMessageId() throws {
        let jwt = try sampleJwt()

        let parsed = try handler.parseMessage(message: jwt)

        XCTAssertNotNil(parsed["messageId"] as? String)
        XCTAssertEqual(parsed["rawJwt"] as? String, jwt)
    }

    func testCanHandleStringRejectsInvalidJwt() {
        XCTAssertFalse(handler.canHandle(message: "invalid.jwt.value"))
    }

    func testSendApprovalDefaultPush() async throws {
        mockResponder.authenticationResult = true
        let notification = makeNotification(pushType: .default)

        let result = try await handler.sendApproval(
            credential: makeCredential(),
            notification: notification,
            params: [:]
        )

        XCTAssertTrue(result)
        XCTAssertEqual(mockResponder.authCalls.count, 1)
        let call = try XCTUnwrap(mockResponder.authCalls.first)
        XCTAssertTrue(call.approve)
        XCTAssertNil(call.challengeResponse)
    }

    func testSendApprovalChallengeRequiresResponse() async {
        let notification = makeNotification(pushType: .challenge)

        do {
            _ = try await handler.sendApproval(
                credential: makeCredential(),
                notification: notification,
                params: [:]
            )
            XCTFail("Expected invalidParameterValue error")
        } catch PushError.invalidParameterValue {
            // expected path
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendDenialCallsResponder() async throws {
        mockResponder.authenticationResult = true
        let notification = makeNotification(pushType: .default)

        let result = try await handler.sendDenial(
            credential: makeCredential(),
            notification: notification,
            params: [:]
        )

        XCTAssertTrue(result)
        XCTAssertEqual(mockResponder.authCalls.count, 1)
        let call = try XCTUnwrap(mockResponder.authCalls.first)
        XCTAssertFalse(call.approve)
    }

    func testSetDeviceTokenUsesDefaultName() async throws {
        mockResponder.updateTokenResult = true

        let result = try await handler.setDeviceToken(
            credential: makeCredential(),
            deviceToken: " device-token ",
            params: [:]
        )

        XCTAssertTrue(result)
        XCTAssertEqual(mockResponder.updateTokenCalls.count, 1)
        let call = try XCTUnwrap(mockResponder.updateTokenCalls.first)
        XCTAssertEqual(call.deviceToken, "device-token")
        XCTAssertEqual(call.deviceName, "iOS Device")
    }

    func testRegisterDelegatesToResponder() async throws {
        mockResponder.registerResult = true

        let params = ["messageId": "id", "deviceId": "token", "challenge": challengeBase64]
        let result = try await handler.register(
            credential: makeCredential(),
            params: params
        )

        XCTAssertTrue(result)
        XCTAssertEqual(mockResponder.registerCalls.count, 1)
    }

    // MARK: - Helpers

    private var challengeBase64: String {
        Data("challenge-value".utf8).base64EncodedString()
    }

    private func sampleJwt() throws -> String {
        let loadBalancer = Data("amlb-cookie-value".utf8).base64EncodedString()
        let claims: [String: Any] = [
            "u": "mechanism-id",
            "c": challengeBase64,
            "t": 180,
            "i": 1_700_000_000,
            "m": "Approve login?",
            "k": "DEFAULT",
            "p": ["nested": "value"],
            "n": "1,2,3",
            "x": "context",
            "l": loadBalancer,
            "d": "user-123",
            "e": "iPhone 16",
            "extraField": "extraValue"
        ]
        return try CompactJwt.signJwtClaims(base64Secret: base64Secret, claims: claims)
    }

    private func makeCredential() -> PushCredential {
        PushCredential(
            id: "credential-id",
            userId: "user-123",
            resourceId: "credential-id",
            issuer: "Ping Identity",
            accountName: "user@example.com",
            serverEndpoint: "https://push.example.com/am/json/push",
            sharedSecret: base64Secret,
            platform: .pingAM
        )
    }

    private func makeNotification(pushType: PushType) -> PushNotification {
        PushNotification(
            id: "notification-id",
            credentialId: "credential-id",
            ttl: 60,
            messageId: "message-123",
            messageText: "Approve login?",
            customPayload: nil,
            challenge: challengeBase64,
            numbersChallenge: "1,2,3",
            loadBalancer: "cookie",
            contextInfo: nil,
            pushType: pushType,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
    }
}

// MARK: - Mock Responder

private final class MockResponder: PingAMPushResponderType, @unchecked Sendable {
    struct AuthCall: Sendable {
        let credential: PushCredential
        let notification: PushNotification
        let approve: Bool
        let challengeResponse: String?
    }

    private(set) var authCalls: [AuthCall] = []
    private(set) var updateTokenCalls: [(credential: PushCredential, deviceToken: String, deviceName: String?)] = []
    private(set) var registerCalls: [(credential: PushCredential, params: [String: Any])] = []

    var authenticationResult: Bool = true
    var updateTokenResult: Bool = true
    var registerResult: Bool = true

    func register(credential: PushCredential, params: [String: Any]) async throws -> Bool {
        registerCalls.append((credential, params))
        return registerResult
    }

    func sendAuthenticationResponse(
        credential: PushCredential,
        notification: PushNotification,
        approve: Bool,
        numbersChallengeResponse: String?
    ) async throws -> Bool {
        authCalls.append(AuthCall(
            credential: credential,
            notification: notification,
            approve: approve,
            challengeResponse: numbersChallengeResponse
        ))
        return authenticationResult
    }

    func updateDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        deviceName: String?
    ) async throws -> Bool {
        updateTokenCalls.append((credential, deviceToken, deviceName))
        return updateTokenResult
    }
}
