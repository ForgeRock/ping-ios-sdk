//
//  PushServiceTests.swift
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

final class PushServiceTests: XCTestCase {

    private var storage: TestInMemoryPushStorage!
    private var configuration: PushConfiguration!
    private var httpClient: HttpClient!
    private var policyEvaluator: MfaPolicyEvaluator!

    override func setUp() async throws {
        try await super.setUp()
        storage = TestInMemoryPushStorage()
        configuration = PushConfiguration()
        httpClient = HttpClient()
        policyEvaluator = MfaPolicyEvaluator.create()
    }

    override func tearDown() async throws {
        storage = nil
        configuration = nil
        httpClient = nil
        policyEvaluator = nil
        try await super.tearDown()
    }

    func testInitializationRegistersDefaultPingAmHandler() async throws {
        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator
        )

        let handlerCount = await service.handlerCount()
        XCTAssertEqual(handlerCount, 1)

        let typeName = await service.handlerTypeName(for: PushPlatform.pingAM.rawValue)
        XCTAssertEqual(typeName, String(describing: PingAMPushHandler.self))
    }

    func testInitializationMergesCustomHandlers() async throws {
        let customHandler = StubPushHandler()
        configuration.customPushHandlers = [
            "CUSTOM": customHandler
        ]

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator
        )

        let handlerCount = await service.handlerCount()
        XCTAssertEqual(handlerCount, 2)

        let defaultType = await service.handlerTypeName(for: PushPlatform.pingAM.rawValue)
        XCTAssertEqual(defaultType, String(describing: PingAMPushHandler.self))

        let customType = await service.handlerTypeName(for: "CUSTOM")
        XCTAssertEqual(customType, String(describing: StubPushHandler.self))
    }

    func testInitializationHonorsInjectedHandlersMap() async throws {
        let injectedHandler = StubPushHandler()

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: injectedHandler
            ]
        )

        let handlerCount = await service.handlerCount()
        XCTAssertEqual(handlerCount, 1)

        let handlerType = await service.handlerTypeName(for: PushPlatform.pingAM.rawValue)
        XCTAssertEqual(handlerType, String(describing: StubPushHandler.self))
    }

    func testAddCredentialFromUriRegistersAndStoresCredential() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)
        try await tokenManager.storeDeviceToken("apns-token-123")

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let uri = "pushauth://push/ForgeRock:stoyan@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&b=032b75&s=oSWY2AY0tHrGUivojn-iahvGC77YDKcA2x6ChSDzwAo&c=jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:9a8e9525-f598-4a7d-a759-1ff86f130cb31755365762960"

        let credential = try await service.addCredentialFromUri(uri)

        XCTAssertEqual(credential.issuer, "ForgeRock")

        let registerCall = stubHandler.lastRegisterCall
        XCTAssertNotNil(registerCall)
        XCTAssertEqual(registerCall?.credential.id, credential.id)
        XCTAssertEqual(registerCall?.params["deviceId"] as? String, "apns-token-123")

        let storedCredentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(storedCredentials.count, 1)
        XCTAssertEqual(storedCredentials.first?.id, credential.id)
    }

    func testAddCredentialEnforcesPolicies() async throws {
        let failingPolicyEvaluator = MfaPolicyEvaluator.create { config in
            config.policies = [MockFailingPolicy()]
        }

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: failingPolicyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0",
            policies: #"{"mockPolicy":{}}"#
        )

        let stored = try await service.addCredential(credential)
        XCTAssertTrue(stored.isLocked)
        XCTAssertEqual(stored.lockingPolicy, "mockPolicy")

        let persisted = try await storage.retrievePushCredential(credentialId: stored.id)
       XCTAssertEqual(persisted?.isLocked, true)
    }

    func testSetDeviceTokenSkipsUpdateWhenUnchanged() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)
        try await tokenManager.storeDeviceToken("existing-token")

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let result = try await service.setDeviceToken("existing-token")

        XCTAssertTrue(result)
        XCTAssertTrue(stubHandler.setDeviceTokenCalls.isEmpty)
    }

    func testSetDeviceTokenUpdatesAllCredentials() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let credentialA = PushCredential(
            issuer: "ForgeRock",
            accountName: "userA@example.com",
            serverEndpoint: "https://example.com/a",
            sharedSecret: "c2VjcmV0QQ=="
        )
        let credentialB = PushCredential(
            issuer: "ForgeRock",
            accountName: "userB@example.com",
            serverEndpoint: "https://example.com/b",
            sharedSecret: "c2VjcmV0Qg=="
        )

        _ = try await service.addCredential(credentialA)
        _ = try await service.addCredential(credentialB)

        let result = try await service.setDeviceToken("new-token")
        XCTAssertTrue(result)
        XCTAssertEqual(stubHandler.setDeviceTokenCalls.count, 2)
        XCTAssertTrue(stubHandler.setDeviceTokenCalls.allSatisfy { $0.deviceToken == "new-token" })

        let storedToken = try await service.getDeviceToken()
        XCTAssertEqual(storedToken, "new-token")
    }

    func testSetDeviceTokenUpdatesSpecificCredential() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )

        let stored = try await service.addCredential(credential)

        let result = try await service.setDeviceToken("single-token", credentialId: stored.id)
        XCTAssertTrue(result)
        XCTAssertEqual(stubHandler.setDeviceTokenCalls.count, 1)
        XCTAssertEqual(stubHandler.setDeviceTokenCalls.first?.credential.id, stored.id)
        XCTAssertEqual(stubHandler.setDeviceTokenCalls.first?.deviceToken, "single-token")
    }

    func testSetDeviceTokenReturnsFalseWhenCredentialMissing() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let result = try await service.setDeviceToken("missing-token", credentialId: "missing-id")
        XCTAssertFalse(result)
        XCTAssertTrue(stubHandler.setDeviceTokenCalls.isEmpty)
    }

    func testSetDeviceTokenReportsHandlerFailure() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.setDeviceTokenResult = false
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )

        _ = try await service.addCredential(credential)

        let result = try await service.setDeviceToken("new-token")
        XCTAssertFalse(result)
        XCTAssertEqual(stubHandler.setDeviceTokenCalls.count, 1)
    }

    func testGetDeviceTokenReturnsNilWhenUnset() async throws {
        let stubHandler = StubPushHandler()
        let tokenManager = PushDeviceTokenManager(storage: storage, logger: nil)

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [
                PushPlatform.pingAM.rawValue: stubHandler
            ]
        )

        let token = try await service.getDeviceToken()
        XCTAssertNil(token)
    }

    func testProcessNotificationMessageDataStoresNotification() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true

        let service = makeService(handler: stubHandler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )
        _ = try await service.addCredential(credential)

        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: credential.id,
            messageId: "msg-data-1"
        )

        let messageData: [String: Any] = [
            "messageId": "msg-data-1",
            "message": "jwt"
        ]

        let notification = try await service.processNotification(messageData: messageData)

        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-data-1")

        let stored = try await storage.getAllPushNotifications()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.messageId, "msg-data-1")
    }

    func testProcessNotificationStringStoresNotification() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageResult = true

        let service = makeService(handler: stubHandler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "jwt@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )
        _ = try await service.addCredential(credential)

        stubHandler.parseMessageStringResult = makeParsedNotificationData(
            credentialId: credential.id,
            messageId: "msg-string-1"
        )

        let notification = try await service.processNotification(message: "jwt-token")
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-string-1")
    }

    func testProcessNotificationUserInfoConvertsKeys() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true

        let service = makeService(handler: stubHandler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "userinfo@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )
        _ = try await service.addCredential(credential)

        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: credential.id,
            messageId: "msg-userinfo"
        )

        let userInfo: [AnyHashable: Any] = [
            "messageId": "msg-userinfo",
            "message": "payload"
        ]

        let notification = try await service.processNotification(userInfo: userInfo)
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.messageId, "msg-userinfo")
    }

    func testProcessNotificationReturnsExistingOnDuplicateMessageId() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true

        let service = makeService(handler: stubHandler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "dup@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )
        _ = try await service.addCredential(credential)

        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: credential.id,
            messageId: "duplicate-id"
        )

        let payload: [String: Any] = [
            "messageId": "duplicate-id",
            "message": "payload"
        ]

        let first = try await service.processNotification(messageData: payload)
        // Create a copy to avoid data race warning with non-Sendable dictionary
        let payloadCopy: [String: Any] = [
            "messageId": "duplicate-id",
            "message": "payload"
        ]
        let second = try await service.processNotification(messageData: payloadCopy)

        XCTAssertEqual(first?.messageId, "duplicate-id")
        XCTAssertEqual(second?.messageId, "duplicate-id")

        let stored = try await storage.getAllPushNotifications()
        XCTAssertEqual(stored.count, 1)
    }

    func testProcessNotificationUpdatesCredentialUserIdWhenMissing() async throws {
        let stubHandler = StubPushHandler()
        stubHandler.canHandleMessageDataResult = true

        let service = makeService(handler: stubHandler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "assign-user@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )
        _ = try await service.addCredential(credential)

        stubHandler.parseMessageDataResult = makeParsedNotificationData(
            credentialId: credential.id,
            messageId: "user-update",
            additional: ["userId": "server-user"]
        )

        let payload: [String: Any] = [
            "messageId": "user-update",
            "message": "payload"
        ]

        _ = try await service.processNotification(messageData: payload)

        let updated = try await storage.retrievePushCredential(credentialId: credential.id)
        XCTAssertEqual(updated?.userId, "server-user")
    }

    func testApproveNotificationMarksNotificationWhenHandlerSucceeds() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "approve@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "approve-success"
        )
        try await storage.storePushNotification(notification)

        let result = try await service.approveNotification(
            notificationId: notification.id,
            params: ["ip": "127.0.0.1"]
        )

        XCTAssertTrue(result)
        XCTAssertEqual(handler.sendApprovalCalls.count, 1)
        XCTAssertEqual(handler.sendApprovalCalls.first?.params["ip"] as? String, "127.0.0.1")

        let stored = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(stored?.approved, true)
        XCTAssertEqual(stored?.pending, false)
        XCTAssertNotNil(stored?.respondedAt)
    }

    func testApproveNotificationReturnsFalseWhenNotificationNotPending() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "already-approved@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "approve-skipped",
            pending: false,
            approved: true
        )
        try await storage.storePushNotification(notification)

        let result = try await service.approveNotification(notificationId: notification.id)

        XCTAssertFalse(result)
        XCTAssertTrue(handler.sendApprovalCalls.isEmpty)
    }

    func testApproveNotificationThrowsWhenCredentialLocked() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "locked@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret",
            lockingPolicy: "biometricOnly",
            isLocked: true
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "approve-locked"
        )
        try await storage.storePushNotification(notification)

        do {
            _ = try await service.approveNotification(notificationId: notification.id)
            XCTFail("Expected credentialLocked error")
        } catch let error as PushError {
            guard case .credentialLocked(let id) = error else {
                XCTFail("Expected credentialLocked error, got \(error)")
                return
            }
            XCTAssertEqual(id, credential.id)
        }
    }

    func testApproveNotificationReturnsFalseWhenHandlerFails() async throws {
        let handler = StubPushHandler()
        handler.sendApprovalResult = false
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "handler-fail@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "approve-handler-fail"
        )
        try await storage.storePushNotification(notification)

        let result = try await service.approveNotification(notificationId: notification.id)

        XCTAssertFalse(result)
        XCTAssertEqual(handler.sendApprovalCalls.count, 1)

        let stored = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(stored?.pending, true)
        XCTAssertEqual(stored?.approved, false)
    }

    func testDenyNotificationMarksNotificationWhenHandlerSucceeds() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "deny@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "deny-success"
        )
        try await storage.storePushNotification(notification)

        let result = try await service.denyNotification(notificationId: notification.id)

        XCTAssertTrue(result)
        XCTAssertEqual(handler.sendDenialCalls.count, 1)

        let stored = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(stored?.approved, false)
        XCTAssertEqual(stored?.pending, false)
        XCTAssertNotNil(stored?.respondedAt)
    }

    func testDenyNotificationReturnsFalseWhenNotificationNotPending() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "deny-skip@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "deny-skip",
            pending: false,
            approved: false
        )
        try await storage.storePushNotification(notification)

        let result = try await service.denyNotification(notificationId: notification.id)

        XCTAssertFalse(result)
        XCTAssertTrue(handler.sendDenialCalls.isEmpty)
    }

    func testDenyNotificationReturnsFalseWhenHandlerFails() async throws {
        let handler = StubPushHandler()
        handler.sendDenialResult = false
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "deny-handler-fail@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(
            credentialId: credential.id,
            messageId: "deny-handler-fail"
        )
        try await storage.storePushNotification(notification)

        let result = try await service.denyNotification(notificationId: notification.id)

        XCTAssertFalse(result)
        XCTAssertEqual(handler.sendDenialCalls.count, 1)

        let stored = try await storage.retrievePushNotification(notificationId: notification.id)
        XCTAssertEqual(stored?.pending, true)
        XCTAssertEqual(stored?.approved, false)
    }

    func testCredentialUnlocksWhenPolicyPasses() async throws {
        let togglablePolicy = MockTogglablePolicy(shouldPass: false)
        let togglableEvaluator = MfaPolicyEvaluator.create { config in
            config.policies = [togglablePolicy]
        }

        let service = PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: togglableEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "toggle@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret",
            policies: #"{"mockTogglable":{}}"#
        )

        let lockedCredential = try await service.addCredential(credential)
        XCTAssertTrue(lockedCredential.isLocked)
        XCTAssertEqual(lockedCredential.lockingPolicy, "mockTogglable")

        togglablePolicy.shouldPass = true

        let credentials = try await service.getCredentials()
        XCTAssertEqual(credentials.count, 1)

        let unlocked = credentials[0]
        XCTAssertFalse(unlocked.isLocked)
        XCTAssertNil(unlocked.lockingPolicy)

        let persisted = try await storage.retrievePushCredential(credentialId: unlocked.id)
        XCTAssertEqual(persisted?.isLocked, false)
        XCTAssertNil(persisted?.lockingPolicy)
    }

    func testGetCredentialsUsesCacheWhenEnabled() async throws {
        let cachedConfig = PushConfiguration()
        cachedConfig.enableCredentialCache = true

        let service = PushService(
            storage: storage,
            configuration: cachedConfig,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "cached@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )

        _ = try await service.addCredential(credential)

        let firstFetch = try await service.getCredentials()
        XCTAssertEqual(firstFetch.count, 1)

        try await storage.clearPushCredentials()

        let cachedFetch = try await service.getCredentials()
        XCTAssertEqual(cachedFetch.count, 1)
        XCTAssertEqual(cachedFetch.first?.id, credential.id)
    }

    func testGetCredentialFallsBackToCache() async throws {
        let cachedConfig = PushConfiguration()
        cachedConfig.enableCredentialCache = true

        let service = PushService(
            storage: storage,
            configuration: cachedConfig,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "single@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )

        let stored = try await service.addCredential(credential)
        XCTAssertNotNil(stored)

        try await storage.clearPushCredentials()

        let cached = try await service.getCredential(credentialId: credential.id)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.id, credential.id)
    }

    func testRemoveCredentialClearsStorageAndCache() async throws {
        let cachedConfig = PushConfiguration()
        cachedConfig.enableCredentialCache = true

        let service = PushService(
            storage: storage,
            configuration: cachedConfig,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "remove@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "c2VjcmV0"
        )

        _ = try await service.addCredential(credential)

        let removed = try await service.removeCredential(credentialId: credential.id)
        XCTAssertTrue(removed)

        let fetched = try await service.getCredential(credentialId: credential.id)
        XCTAssertNil(fetched)

        let storedCredentials = try await storage.getAllPushCredentials()
        XCTAssertTrue(storedCredentials.isEmpty)
    }

    func testClearCacheRemovesCachedCredentials() async throws {
        let cachedConfig = PushConfiguration()
        cachedConfig.enableCredentialCache = true

        let service = PushService(
            storage: storage,
            configuration: cachedConfig,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: nil,
            handlers: [
                PushPlatform.pingAM.rawValue: StubPushHandler()
            ]
        )

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "cache@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )

        _ = try await service.addCredential(credential)

        let firstFetch = try await service.getCredentials()
        XCTAssertEqual(firstFetch.count, 1)

        _ = try await storage.removePushCredential(credentialId: credential.id)

        let cachedFetch = try await service.getCredentials()
        XCTAssertEqual(cachedFetch.count, 1)

        await service.clearCache()

        let afterClear = try await service.getCredentials()
        XCTAssertTrue(afterClear.isEmpty)
    }

    func testGetPendingNotificationsReturnsPendingOnly() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "pending@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let pendingNotification = makeNotification(
            credentialId: credential.id,
            messageId: "pending-1"
        )
        var approvedNotification = makeNotification(
            credentialId: credential.id,
            messageId: "approved-1"
        )
        approvedNotification.markApproved()

        try await storage.storePushNotification(pendingNotification)
        try await storage.storePushNotification(approvedNotification)

        let pending = try await service.getPendingNotifications()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.messageId, "pending-1")
    }

    func testGetAllNotificationsReturnsEveryStoredNotification() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "all@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let first = makeNotification(credentialId: credential.id, messageId: "first")
        var second = makeNotification(credentialId: credential.id, messageId: "second")
        second.markDenied()

        try await storage.storePushNotification(first)
        try await storage.storePushNotification(second)

        let all = try await service.getAllNotifications()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(where: { $0.messageId == "first" }))
        XCTAssertTrue(all.contains(where: { $0.messageId == "second" }))
    }

    func testGetNotificationReturnsNilWhenMissing() async throws {
        let handler = StubPushHandler()
        let service = makeService(handler: handler)

        let credential = PushCredential(
            issuer: "ForgeRock",
            accountName: "single@example.com",
            serverEndpoint: "https://example.com",
            sharedSecret: "secret"
        )
        _ = try await service.addCredential(credential)

        let notification = makeNotification(credentialId: credential.id, messageId: "lookup")
        try await storage.storePushNotification(notification)

        let found = try await service.getNotification(notificationId: notification.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.messageId, "lookup")

        let missing = try await service.getNotification(notificationId: UUID().uuidString)
        XCTAssertNil(missing)
    }
}

private final class StubPushHandler: PushHandler, @unchecked Sendable {

    var lastRegisterCall: (credential: PushCredential, params: [String: Any])?
    var registerResult: Bool = true
    var setDeviceTokenResult: Bool = true
    var setDeviceTokenCalls: [(credential: PushCredential, deviceToken: String, params: [String: Any])] = []
    var canHandleMessageDataResult = false
    var canHandleMessageResult = false
    var parseMessageDataResult: [String: Any] = [:]
    var parseMessageStringResult: [String: Any] = [:]
    var lastParsedMessageData: [String: Any]?
    var lastParsedMessageString: String?
    var sendApprovalResult: Bool = true
    var sendApprovalError: Error?
    var sendApprovalCalls: [(credential: PushCredential, notification: PushNotification, params: [String: Any])] = []
    var sendDenialResult: Bool = true
    var sendDenialError: Error?
    var sendDenialCalls: [(credential: PushCredential, notification: PushNotification, params: [String: Any])] = []

    func canHandle(messageData: [String: Any]) -> Bool {
        canHandleMessageDataResult
    }

    func canHandle(message: String) -> Bool {
        canHandleMessageResult
    }

    func parseMessage(messageData: [String: Any]) throws -> [String: Any] {
        lastParsedMessageData = messageData
        return parseMessageDataResult
    }

    func parseMessage(message: String) throws -> [String: Any] {
        lastParsedMessageString = message
        return parseMessageStringResult
    }

    func sendApproval(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        sendApprovalCalls.append((credential, notification, params))
        if let error = sendApprovalError {
            throw error
        }
        return sendApprovalResult
    }

    func sendDenial(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        sendDenialCalls.append((credential, notification, params))
        if let error = sendDenialError {
            throw error
        }
        return sendDenialResult
    }

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
        lastRegisterCall = (credential, params)
        return registerResult
    }
}

private struct MockFailingPolicy: MfaPolicy {
    let name = "mockPolicy"

    func evaluate(data: [String: Any]?) async throws -> Bool {
        false
    }
}

private final class MockTogglablePolicy: MfaPolicy, @unchecked Sendable {
    let name = "mockTogglable"
    var shouldPass: Bool

    init(shouldPass: Bool) {
        self.shouldPass = shouldPass
    }

    func evaluate(data: [String: Any]?) async throws -> Bool {
        shouldPass
    }
}

private extension PushServiceTests {

    func makeService(
        handler: StubPushHandler,
        configuration overrideConfiguration: PushConfiguration? = nil,
        tokenManager: PushDeviceTokenManager? = nil
    ) -> PushService {
        let config = (overrideConfiguration ?? self.configuration)!
        return PushService(
            storage: storage,
            configuration: config,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator,
            deviceTokenManager: tokenManager,
            handlers: [PushPlatform.pingAM.rawValue: handler]
        )
    }

    func makeParsedNotificationData(
        credentialId: String,
        messageId: String,
        additional: [String: Any] = [:]
    ) -> [String: Any] {
        var data: [String: Any] = [
            "credentialId": credentialId,
            "messageId": messageId,
            "ttl": 120,
            "messageText": "Approve login?",
            "pushType": "default"
        ]

        additional.forEach { data[$0.key] = $0.value }
        return data
    }

    func makeNotification(
        credentialId: String,
        messageId: String,
        pending: Bool = true,
        approved: Bool = false
    ) -> PushNotification {
        PushNotification(
            credentialId: credentialId,
            ttl: 120,
            messageId: messageId,
            messageText: "Approve login?",
            pushType: .default,
            approved: approved,
            pending: pending
        )
    }
}
