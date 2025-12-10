//
//  PushClientTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushClientTests: XCTestCase {

    func testCreateClientWithCustomStorageInitializesSuccessfully() async throws {
        let storage = TestInMemoryPushStorage()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.logger = nil
        }

        XCTAssertTrue(client.storageProvider is TestInMemoryPushStorage)
        XCTAssertNoThrow(try client.checkInitialized())
    }

    func testCreateClientAppliesConfigurationBuilderChanges() async throws {
        let client = try await PushClient.createClient { config in
            config.timeoutMs = 45_000
            config.enableCredentialCache = true
            config.storage = TestInMemoryPushStorage()
        }

        XCTAssertEqual(client.configurationSnapshot.timeoutMs, 45_000)
        XCTAssertTrue(client.configurationSnapshot.enableCredentialCache)
    }

    func testCreateClientWithPrebuiltConfiguration() async throws {
        let configuration = PushConfiguration.build { config in
            config.timeoutMs = 12_000
            config.storage = TestInMemoryPushStorage()
        }

        let client = try await PushClient.createClient(configuration: configuration)

        XCTAssertEqual(client.configurationSnapshot.timeoutMs, 12_000)
        XCTAssertTrue(client.storageProvider is TestInMemoryPushStorage)
    }

    func testSaveGetAndDeleteCredential() async throws {
        let client = try await PushClient.createClient { config in
            config.storage = TestInMemoryPushStorage()
        }

        let credential = PushCredential(
            id: "cred-save-1",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )

        let saved = try await client.saveCredential(credential)
        XCTAssertEqual(saved.id, credential.id)

        let allCredentials = try await client.getCredentials()
        XCTAssertEqual(allCredentials.count, 1)
        XCTAssertEqual(allCredentials.first?.id, credential.id)

        let fetched = try await client.getCredential(credentialId: credential.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, credential.id)

        let removed = try await client.deleteCredential(credentialId: credential.id)
        XCTAssertTrue(removed)

        let missing = try await client.getCredential(credentialId: credential.id)
        XCTAssertNil(missing)
    }

    func testSetAndGetDeviceToken() async throws {
        let client = try await PushClient.createClient { config in
            config.storage = TestInMemoryPushStorage()
        }

        let updated = try await client.setDeviceToken("token-123")
        XCTAssertTrue(updated)

        let fetched = try await client.getDeviceToken()
        XCTAssertEqual(fetched, "token-123")
    }

    func testProcessNotificationRunsAutoCleanup() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true
        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: "cred-123",
            messageId: "msg-latest"
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .countBased(maxNotifications: 1)
        }

        let oldNotification1 = PushNotification(
            credentialId: "cred-123",
            ttl: 120,
            messageId: "old-1",
            pushType: .default,
            createdAt: Date(timeIntervalSinceNow: -200)
        )
        let oldNotification2 = PushNotification(
            credentialId: "cred-123",
            ttl: 120,
            messageId: "old-2",
            pushType: .default,
            createdAt: Date(timeIntervalSinceNow: -100)
        )

        try await storage.storePushNotification(oldNotification1)
        try await storage.storePushNotification(oldNotification2)

        let notification = try await client.processNotification(messageData: ["message": "jwt"])
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-latest")

        // Wait for async cleanup task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.messageId, "msg-latest")
    }

    func testProcessNotificationStringUsesHandler() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageResult = true
        stubHandler.parseMessageStringResult = makeParsedNotificationData(
            credentialId: "cred-string",
            messageId: "msg-string"
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .none()
        }

        let notification = try await client.processNotification(message: "encoded-token")
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-string")
    }

    func testProcessNotificationUserInfoDelegatesToMessageData() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true
        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: "cred-userinfo",
            messageId: "msg-userinfo"
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .none()
        }

        let userInfo: [AnyHashable: Any] = [
            "dummy": "value"
        ]

        let notification = try await client.processNotification(userInfo: userInfo)
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-userinfo")
    }

    func testProcessNotificationUserInfoExtractsAPNsPayload() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true
        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: "cred-apns",
            messageId: "apns-msg-123"
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .none()
        }

        // Simulate APNs userInfo format with nested aps dictionary
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Login attempt from Chrome",
                "sound": "default",
                "data": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
                "messageId": "apns-msg-123"
            ]
        ]

        let notification = try await client.processNotification(userInfo: userInfo)
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "apns-msg-123")
        
        // Verify handler received extracted payload (message and messageId at root level)
        XCTAssertTrue(stubHandler.canHandleMessageDataResult)
    }

    func testProcessNotificationUserInfoHandlesMissingAPsFields() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = false // Handler will reject incomplete data

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .none()
        }

        // APNs payload missing required fields
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Test notification",
                "sound": "default"
                // Missing "data" and "messageId"
            ]
        ]

        let notification = try await client.processNotification(userInfo: userInfo)
        // Should return nil when handler cannot process
        XCTAssertNil(notification)
    }

    func testProcessNotificationUserInfoPreservesNonAPsKeys() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true
        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: "cred-mixed",
            messageId: "mixed-msg-456"
        )

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
            config.notificationCleanupConfig = .none()
        }

        // APNs payload with additional top-level keys
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "data": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
                "messageId": "mixed-msg-456"
            ],
            "customKey": "customValue",
            "anotherKey": 123
        ]

        let notification = try await client.processNotification(userInfo: userInfo)
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "mixed-msg-456")
    }

    func testApproveNotificationMarksNotificationAsApproved() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "approve@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "approve-1",
            pushType: .default
        )

        try await storage.storePushNotification(notification)

        let result = try await client.approveNotification(notification.id)
        XCTAssertTrue(result)

        let updated = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(updated?.approved, true)
        XCTAssertEqual(updated?.pending, false)
        XCTAssertNil(stubHandler.lastApprovalParams?["challengeResponse"])
    }

    func testApproveChallengeNotificationRequiresNonEmptyResponse() async throws {
        let client = try await PushClient.createClient { config in
            config.storage = TestInMemoryPushStorage()
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        }

        await XCTAssertThrowsErrorAsync({
            _ = try await client.approveChallengeNotification("notification-id", challengeResponse: "   ")
        }) { error in
            guard case PushError.invalidParameterValue = error else {
                XCTFail("Expected invalidParameterValue, got \(error)")
                return
            }
        }
    }

    func testApproveChallengeNotificationPassesResponseToHandler() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "challenge@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "challenge-1",
            pushType: .challenge
        )

        try await storage.storePushNotification(notification)

        let result = try await client.approveChallengeNotification(notification.id, challengeResponse: " 4321 ")
        XCTAssertTrue(result)

        XCTAssertEqual(stubHandler.lastApprovalParams?["challengeResponse"] as? String, "4321")
    }

    func testApproveBiometricNotificationPassesMethodToHandler() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "biometric@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "biometric-1",
            pushType: .biometric
        )

        try await storage.storePushNotification(notification)

        let result = try await client.approveBiometricNotification(notification.id, authenticationMethod: " face ")
        XCTAssertTrue(result)

        XCTAssertEqual(stubHandler.lastApprovalParams?["authenticationMethod"] as? String, "face")
    }

    func testDenyNotificationMarksNotificationAsDenied() async throws {
        let storage = TestInMemoryPushStorage()
        let stubHandler = StubPushHandler()

        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.customPushHandlers = [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "deny@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "deny-1",
            pushType: .default
        )

        try await storage.storePushNotification(notification)

        let result = try await client.denyNotification(notification.id)
        XCTAssertTrue(result)

        let updated = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(updated?.approved, false)
        XCTAssertEqual(updated?.pending, false)
        XCTAssertTrue(stubHandler.lastDenialCalled)
    }

    func testGetPendingNotificationsReturnsOnlyPending() async throws {
        let storage = TestInMemoryPushStorage()
        let client = try await PushClient.createClient { config in
            config.storage = storage
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "pending@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let pending = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "pending-ntf",
            pushType: .default
        )

        var responded = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "responded-ntf",
            pushType: .default
        )
        responded.markDenied()

        try await storage.storePushNotification(pending)
        try await storage.storePushNotification(responded)

        let results = try await client.getPendingNotifications()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.messageId, "pending-ntf")
    }

    func testGetAllNotificationsReturnsStoredNotifications() async throws {
        let storage = TestInMemoryPushStorage()
        let client = try await PushClient.createClient { config in
            config.storage = storage
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "all@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let first = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "all-1",
            pushType: .default
        )
        let second = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "all-2",
            pushType: .default
        )

        try await storage.storePushNotification(first)
        try await storage.storePushNotification(second)

        let results = try await client.getAllNotifications()
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.messageId == "all-1" }))
        XCTAssertTrue(results.contains(where: { $0.messageId == "all-2" }))
    }

    func testGetNotificationReturnsSpecificNotification() async throws {
        let storage = TestInMemoryPushStorage()
        let client = try await PushClient.createClient { config in
            config.storage = storage
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "single@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let notification = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "single-ntf",
            pushType: .default
        )

        try await storage.storePushNotification(notification)

        let found = try await client.getNotification(notificationId: notification.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.messageId, "single-ntf")

        let missing = try await client.getNotification(notificationId: "missing")
        XCTAssertNil(missing)
    }

    func testCleanupNotificationsReturnsRemovedCount() async throws {
        let storage = TestInMemoryPushStorage()
        let client = try await PushClient.createClient { config in
            config.storage = storage
            config.notificationCleanupConfig = .countBased(maxNotifications: 1)
        }

        let credential = try await client.saveCredential(
            PushCredential(
                issuer: "ForgeRock",
                accountName: "cleanup@example.com",
                serverEndpoint: "https://example.com",
                sharedSecret: "secret"
            )
        )

        let first = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "cleanup-1",
            pushType: .default
        )
        let second = PushNotification(
            credentialId: credential.id,
            ttl: 120,
            messageId: "cleanup-2",
            pushType: .default
        )

        try await storage.storePushNotification(first)
        try await storage.storePushNotification(second)

        let removed = try await client.cleanupNotifications(credentialId: credential.id)
        XCTAssertEqual(removed, 1)
    }
}

// MARK: - Test Helpers

private final class StubPushHandler: PushHandler, @unchecked Sendable {

    var canHandleMessageDataResult = false
    var canHandleMessageResult = false
    var parseMessageDataResult: [String: Any] = [:]
    var parseMessageStringResult: [String: Any] = [:]
    var sendApprovalResult: Bool = true
    var sendDenialResult: Bool = true
    var lastApprovalParams: [String: Any]? = nil
    var lastDenialCalled: Bool = false

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
        lastApprovalParams = params
        return sendApprovalResult
    }

    func sendDenial(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        lastDenialCalled = true
        return sendDenialResult
    }

    func setDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        params: [String: Any]
    ) async throws -> Bool { true }

    func register(
        credential: PushCredential,
        params: [String: Any]
    ) async throws -> Bool { true }
}

private func makeParsedNotificationData(
    credentialId: String,
    messageId: String
) -> [String: Any] {
    [
        "credentialId": credentialId,
        "messageId": messageId,
        "ttl": 120,
        "messageText": "Approve?",
        "pushType": "default"
    ]
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
