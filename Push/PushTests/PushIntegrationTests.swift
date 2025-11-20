//
//  PushIntegrationTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights
//  reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingMfaCommons
@testable import PingPush

final class PushIntegrationTests: XCTestCase {

    private let sampleUri = """
    pushauth://push/ForgeRock:stoyan@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&b=032b75&s=oSWY2AY0tHrGUivojn-iahvGC77YDKcA2x6ChSDzwAo&c=jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:9a8e9525-f598-4a7d-a759-1ff86f130cb31755365762960
    """

    // MARK: - Tests

    func testRegistrationFlowStoresCredential() async throws {
        let storage = TestInMemoryPushStorage()
        let handler = IntegrationPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
        }

        _ = try await client.setDeviceToken("device-token")

        let credential = try await client.addCredentialFromUri(sampleUri)

        XCTAssertEqual(handler.registerCalls.count, 1)
        XCTAssertEqual(handler.registerCalls.first?.credential.id, credential.id)

        let stored = try await storage.getAllPushCredentials()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, credential.id)
    }

    func testNotificationProcessingApprovesFlow() async throws {
        let storage = TestInMemoryPushStorage()
        let handler = IntegrationPushHandler()
        handler.canHandleMessageDataResult = true
        handler.parseMessageDataResult = [
            "credentialId": "cred-notify",
            "messageId": "message-001",
            "ttl": 120,
            "pushType": "default"
        ]

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
            config.notificationCleanupConfig = .countBased(maxNotifications: 1)
        }

        let credential = PushCredential(
            id: "cred-notify",
            issuer: "ForgeRock",
            accountName: "notify@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await client.saveCredential(credential)

        let notification = try await client.processNotification(messageData: ["message": "payload"])
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "message-001")

        handler.sendApprovalResult = true
        let approved = try await client.approveNotification(notification!.id)
        XCTAssertTrue(approved)
        XCTAssertTrue(handler.sendApprovalCalled)

        let storedNotifications = try await storage.getAllPushNotifications()
        XCTAssertEqual(storedNotifications.count, 1)
    }

    func testApproveNotificationNetworkFailurePropagatesError() async throws {
        struct DummyError: Error {}

        let storage = TestInMemoryPushStorage()
        let handler = IntegrationPushHandler()
        handler.canHandleMessageDataResult = true
        handler.parseMessageDataResult = [
            "credentialId": "cred-network",
            "messageId": "network-msg",
            "ttl": 120,
            "pushType": "default"
        ]
        handler.sendApprovalResult = false

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
        }

        let credential = PushCredential(
            id: "cred-network",
            issuer: "ForgeRock",
            accountName: "network@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await client.saveCredential(credential)

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "network-msg",
            pushType: .default
        )
        try await storage.storePushNotification(notification)

        handler.errorToThrow = DummyError()

        await XCTAssertThrowsErrorAsync({ _ = try await client.approveNotification(notification.id) }) { error in
            // The error should be thrown - either as DummyError or wrapped in PushError
            XCTAssertTrue(error is DummyError || error is PushError, "Expected DummyError or PushError but got \(type(of: error))")
        }
    }

    func testRegistrationFailsWithEmptyUri() async throws {
        let storage = TestInMemoryPushStorage()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: IntegrationPushHandler()]
        }

        await XCTAssertThrowsErrorAsync({ _ = try await client.addCredentialFromUri("   ") }) { error in
            guard case PushError.invalidUri = error else {
                XCTFail("Expected invalidUri, got \(error)")
                return
            }
        }
    }

    func testDeviceTokenUpdateFlowInvokesHandler() async throws {
        let storage = TestInMemoryPushStorage()
        let handler = IntegrationPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "token@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        // First set without credential to persist token.
        _ = try await client.setDeviceToken("initial-token")

        // Update for specific credential.
        handler.setDeviceTokenResult = true
        let result = try await client.setDeviceToken("updated-token", credentialId: credential.id)
        XCTAssertTrue(result)
        XCTAssertEqual(handler.setDeviceTokenCalls.count, 2)
        XCTAssertEqual(handler.setDeviceTokenCalls.last?.credential.id, credential.id)
        XCTAssertEqual(handler.setDeviceTokenCalls.last?.deviceToken, "updated-token")
    }

    func testSetDeviceTokenThrowsWhenEmpty() async throws {
        let client = try await PushClient.createClient { config in
            config.storage = TestInMemoryPushStorage()
        }

        await XCTAssertThrowsErrorAsync({ _ = try await client.setDeviceToken("   ") }) { error in
            guard case PushError.invalidParameterValue = error else {
                XCTFail("Expected invalidParameterValue, got \(error)")
                return
            }
        }
    }

    func testProcessNotificationFlagsExpiredMessage() async throws {
        let storage = TestInMemoryPushStorage()
        
        let client = try await PushClient.createClient { config in
            config.storage = storage
        }

        let credential = PushCredential(
            id: "cred-expired",
            issuer: "ForgeRock",
            accountName: "expired@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await client.saveCredential(credential)

        // Create a notification with an old createdAt timestamp (5 minutes ago)
        // and TTL of 120 seconds, which should make it expired
        let expiredNotification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "expired-msg",
            pushType: .default,
            createdAt: Date().addingTimeInterval(-300)
        )
        
        try await storage.storePushNotification(expiredNotification)
        
        let retrieved = try await client.getNotification(notificationId: expiredNotification.id)
        XCTAssertNotNil(retrieved)
        // Notification should be expired since it was created 300 seconds ago with TTL of 120
        XCTAssertTrue(retrieved?.isExpired ?? false, "Notification should be expired")
    }

    func testCredentialLifecyclePolicyEvaluationLocksCredential() async throws {
        let storage = TestInMemoryPushStorage()
        let failingPolicy = MockFailingPolicy()
        let evaluator = MfaPolicyEvaluator.create { config in
            config.policies = [failingPolicy]
        }

        let handler = IntegrationPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.policyEvaluator = evaluator
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
        }

        _ = try await client.setDeviceToken("policy-token")

        let policiesJson = #"{"mockFailing": {}}"#
        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "policy@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret",
                policies: policiesJson
            )
        )

        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.lockingPolicy, failingPolicy.name)

        let stored = try await client.getCredentials()
        XCTAssertEqual(stored.count, 1)
        XCTAssertTrue(stored.first?.isLocked ?? false)
    }

    func testApproveNotificationThrowsWhenCredentialLocked() async throws {
        let storage = TestInMemoryPushStorage()
        let handler = IntegrationPushHandler()

        let lockedCredential = PushCredential(
            id: "locked-cred",
            issuer: "ForgeRock",
            accountName: "locked@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret",
            lockingPolicy: "mockFailing",
            isLocked: true
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [PushPlatform.pingAM.rawValue: handler]
        }

        try await storage.storePushCredential(lockedCredential)

        let notification = PushNotification(
            credentialId: lockedCredential.id,
            ttl: 120,
            messageId: "locked-msg",
            pushType: .default
        )
        try await storage.storePushNotification(notification)

        await XCTAssertThrowsErrorAsync({ _ = try await client.approveNotification(notification.id) }) { error in
            guard case PushError.credentialLocked = error else {
                XCTFail("Expected credentialLocked, got \(error)")
                return
            }
        }
    }
}

// MARK: - Helpers

private final class IntegrationPushHandler: PushHandler, @unchecked Sendable {

    var canHandleMessageDataResult = false
    var canHandleMessageResult = false
    var parseMessageDataResult: [String: Any] = [:]
    var parseMessageStringResult: [String: Any] = [:]
    var errorToThrow: Error?

    var registerCalls: [(credential: PushCredential, params: [String: Any])] = []
    var setDeviceTokenCalls: [(credential: PushCredential, deviceToken: String, params: [String: Any])] = []
    var sendApprovalCalled = false

    var sendApprovalResult: Bool = true
    var setDeviceTokenResult: Bool = true

    func canHandle(messageData: [String: Any]) -> Bool {
        canHandleMessageDataResult
    }

    func canHandle(message: String) -> Bool {
        canHandleMessageResult
    }

    func parseMessage(messageData: [String: Any]) throws -> [String: Any] {
        parseMessageDataResult
    }

    func parseMessage(message: String) throws -> [String: Any] {
        parseMessageStringResult
    }

    func sendApproval(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        if let error = errorToThrow {
            throw error
        }
        sendApprovalCalled = true
        return sendApprovalResult
    }

    func sendDenial(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool { true }

    func setDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        params: [String: Any]
    ) async throws -> Bool {
        setDeviceTokenCalls.append((credential, deviceToken, params))
        return setDeviceTokenResult
    }

    func register(
        credential: PushCredential,
        params: [String: Any]
    ) async throws -> Bool {
        registerCalls.append((credential, params))
        return true
    }
}

private struct MockFailingPolicy: MfaPolicy, @unchecked Sendable {
    let name = "mockFailing"

    func evaluate(data: [String: Any]?) async throws -> Bool {
        false
    }
}

// MARK: - Test Helpers

@discardableResult
private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async -> Bool {
    do {
        try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
        return false
    } catch {
        errorHandler(error)
        return true
    }
}
