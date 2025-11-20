//
//  PushKeychainStorageTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

/// Unit tests for PushKeychainStorage - Part 1: Initialization and Keychain Helpers
final class PushKeychainStorageTests: XCTestCase {
    
    var storage: PushKeychainStorage!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create storage with test service identifiers
        storage = PushKeychainStorage(
            credentialService: "com.pingidentity.push.test.credentials",
            notificationService: "com.pingidentity.push.test.notifications",
            tokenService: "com.pingidentity.push.test.tokens"
        )
        
        // Clean up any existing test data
        try? await storage.clearPushCredentials()
        try? await storage.clearPushNotifications()
        try? await storage.clearPushDeviceTokens()
    }
    
    override func tearDown() async throws {
        // Clean up test data
        try? await storage.clearPushCredentials()
        try? await storage.clearPushNotifications()
        try? await storage.clearPushDeviceTokens()
        storage = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithDefaults() {
        let defaultStorage = PushKeychainStorage()
        XCTAssertNotNil(defaultStorage, "Storage should initialize with default values")
    }
    
    func testInitializationWithCustomServices() {
        let customStorage = PushKeychainStorage(
            credentialService: "custom.credentials",
            notificationService: "custom.notifications",
            tokenService: "custom.tokens"
        )
        XCTAssertNotNil(customStorage, "Storage should initialize with custom service identifiers")
    }
    
    func testInitializationWithAccessGroup() {
        let groupStorage = PushKeychainStorage(
            accessGroup: "com.pingidentity.push.test.group"
        )
        XCTAssertNotNil(groupStorage, "Storage should initialize with access group")
    }
    
    func testInitializationWithCustomAccessibility() {
        let accessibleStorage = PushKeychainStorage(
            accessibility: kSecAttrAccessibleAfterFirstUnlock
        )
        XCTAssertNotNil(accessibleStorage, "Storage should initialize with custom accessibility")
    }
    
    // Note: Tests for keychain helper methods (store, load, delete) will be implicitly tested
    // through the CRUD operation tests in subsequent tasks (13-16).
    // Direct testing of private helper methods is not possible, but their functionality
    // will be validated through the public API tests below.
    
    // MARK: - Credential CRUD Operations Tests (Task 13)
    
    func testStorePushCredential() async throws {
        // Given
        let credential = PushCredential(
            id: "test-credential-1",
            userId: "user123",
            resourceId: "test-credential-1",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser",
            displayAccountName: "Test User",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "test-secret-123",
            platform: .pingAM
        )
        
        // When
        try await storage.storePushCredential(credential)
        
        // Then
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        XCTAssertNotNil(retrieved, "Stored credential should be retrievable")
        XCTAssertEqual(retrieved?.id, credential.id)
        XCTAssertEqual(retrieved?.userId, credential.userId)
        XCTAssertEqual(retrieved?.issuer, credential.issuer)
        XCTAssertEqual(retrieved?.accountName, credential.accountName)
    }
    
    func testStorePushCredentialWithOptionalFields() async throws {
        // Given
        let credential = PushCredential(
            id: "test-credential-2",
            userId: "user456",
            resourceId: "test-credential-2",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser2",
            displayAccountName: "Test User 2",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "test-secret-456",
            imageURL: "https://test.example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"biometric\":true}",
            platform: .pingAM
        )
        
        // When
        try await storage.storePushCredential(credential)
        
        // Then
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.imageURL, credential.imageURL)
        XCTAssertEqual(retrieved?.backgroundColor, credential.backgroundColor)
        XCTAssertEqual(retrieved?.policies, credential.policies)
    }
    
    func testStorePushCredentialOverwritesExisting() async throws {
        // Given - First credential
        let credential1 = PushCredential(
            id: "test-credential-3",
            userId: "user789",
            resourceId: "test-credential-3",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "original",
            displayAccountName: "Original",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret-1",
            platform: .pingAM
        )
        try await storage.storePushCredential(credential1)
        
        // When - Store updated credential with same ID
        let credential2 = PushCredential(
            id: "test-credential-3",
            userId: "user789",
            resourceId: "test-credential-3",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "updated",
            displayAccountName: "Updated",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret-2",
            platform: .pingAM
        )
        try await storage.storePushCredential(credential2)
        
        // Then
        let retrieved = try await storage.retrievePushCredential(credentialId: credential1.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.accountName, "updated", "Credential should be overwritten")
    }
    
    func testGetAllPushCredentials() async throws {
        // Given
        let credential1 = PushCredential(
            id: "test-credential-4",
            userId: "user1",
            resourceId: "test-credential-4",
            issuer: "Issuer1",
            displayIssuer: "Issuer 1",
            accountName: "user1",
            displayAccountName: "User 1",
            serverEndpoint: "https://test1.example.com/push",
            sharedSecret: "secret1",
            platform: .pingAM
        )
        
        let credential2 = PushCredential(
            id: "test-credential-5",
            userId: "user2",
            resourceId: "test-credential-5",
            issuer: "Issuer2",
            displayIssuer: "Issuer 2",
            accountName: "user2",
            displayAccountName: "User 2",
            serverEndpoint: "https://test2.example.com/push",
            sharedSecret: "secret2",
            platform: .pingAM
        )
        
        // When
        try await storage.storePushCredential(credential1)
        try await storage.storePushCredential(credential2)
        
        // Then
        let allCredentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(allCredentials.count, 2, "Should retrieve all stored credentials")
        XCTAssertTrue(allCredentials.contains(where: { $0.id == credential1.id }))
        XCTAssertTrue(allCredentials.contains(where: { $0.id == credential2.id }))
    }
    
    func testGetAllPushCredentialsReturnsEmptyWhenNoneStored() async throws {
        // When
        let credentials = try await storage.getAllPushCredentials()
        
        // Then
        XCTAssertTrue(credentials.isEmpty, "Should return empty array when no credentials stored")
    }
    
    func testRetrievePushCredentialByID() async throws {
        // Given
        let credential = PushCredential(
            id: "test-credential-6",
            userId: "user123",
            resourceId: "test-credential-6",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser",
            displayAccountName: "Test User",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret",
            platform: .pingAM
        )
        try await storage.storePushCredential(credential)
        
        // When
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, credential.id)
        XCTAssertEqual(retrieved?.userId, credential.userId)
    }
    
    func testRetrievePushCredentialReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await storage.retrievePushCredential(credentialId: "non-existent-id")
        
        // Then
        XCTAssertNil(retrieved, "Should return nil for non-existent credential")
    }
    
    func testRemovePushCredential() async throws {
        // Given
        let credential = PushCredential(
            id: "test-credential-7",
            userId: "user123",
            resourceId: "test-credential-7",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser",
            displayAccountName: "Test User",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret",
            platform: .pingAM
        )
        try await storage.storePushCredential(credential)
        
        // When
        let removed = try await storage.removePushCredential(credentialId: credential.id)
        
        // Then
        XCTAssertTrue(removed, "Should return true when credential is removed")
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        XCTAssertNil(retrieved, "Removed credential should not be retrievable")
    }
    
    func testRemovePushCredentialReturnsFalseForNonExistent() async throws {
        // When
        let removed = try await storage.removePushCredential(credentialId: "non-existent-id")
        
        // Then
        XCTAssertFalse(removed, "Should return false when credential doesn't exist")
    }
    
    func testClearPushCredentials() async throws {
        // Given - Store multiple credentials
        for i in 1...3 {
            let credential = PushCredential(
                id: "test-credential-clear-\(i)",
                userId: "user\(i)",
                resourceId: "test-credential-clear-\(i)",
                issuer: "Issuer\(i)",
                displayIssuer: "Issuer \(i)",
                accountName: "user\(i)",
                displayAccountName: "User \(i)",
                serverEndpoint: "https://test\(i).example.com/push",
                sharedSecret: "secret\(i)",
                platform: .pingAM
            )
            try await storage.storePushCredential(credential)
        }
        
        // Verify credentials are stored
        var credentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(credentials.count, 3)
        
        // When
        try await storage.clearPushCredentials()
        
        // Then
        credentials = try await storage.getAllPushCredentials()
        XCTAssertTrue(credentials.isEmpty, "All credentials should be cleared")
    }
    
    func testClearPushCredentialsDoesNotThrowWhenEmpty() async throws {
        // When/Then - Should not throw
        try await storage.clearPushCredentials()
    }
    
    func testCredentialDateEncoding() async throws {
        // Given
        let createdAt = Date()
        let credential = PushCredential(
            id: "test-credential-date",
            userId: "user123",
            resourceId: "test-credential-date",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser",
            displayAccountName: "Test User",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret",
            createdAt: createdAt,
            platform: .pingAM
        )
        
        // When
        try await storage.storePushCredential(credential)
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        // Date comparison with tolerance for ISO8601 encoding/decoding
        let timeDifference = abs(retrieved!.createdAt.timeIntervalSince(createdAt))
        XCTAssertLessThan(timeDifference, 1.0, "Dates should be approximately equal after encoding/decoding")
    }
    
    func testCredentialLockedState() async throws {
        // Given
        var credential = PushCredential(
            id: "test-credential-locked",
            userId: "user123",
            resourceId: "test-credential-locked",
            issuer: "TestIssuer",
            displayIssuer: "Test Issuer",
            accountName: "testuser",
            displayAccountName: "Test User",
            serverEndpoint: "https://test.example.com/push",
            sharedSecret: "secret",
            platform: .pingAM
        )
        credential.lockCredential(policyName: "TestPolicy")
        
        // When
        try await storage.storePushCredential(credential)
        let retrieved = try await storage.retrievePushCredential(credentialId: credential.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved!.isLocked, "Credential should be locked")
        XCTAssertEqual(retrieved!.lockingPolicy, "TestPolicy")
    }
    
    // MARK: - Notification Operations Tests
    
    func testStorePushNotification() async throws {
        // Given
        let notification = PushNotification(
            id: "notif-1",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-123",
            messageText: "Login request",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        // When
        try await storage.storePushNotification(notification)
        
        // Then
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "notif-1")
        XCTAssertEqual(retrieved?.credentialId, "cred-1")
        XCTAssertEqual(retrieved?.messageId, "msg-123")
        XCTAssertEqual(retrieved?.messageText, "Login request")
        XCTAssertEqual(retrieved?.pushType, .default)
        XCTAssertTrue(retrieved!.pending)
        XCTAssertFalse(retrieved!.approved)
    }
    
    func testStorePushNotificationWithOptionalFields() async throws {
        // Given
        let notification = PushNotification(
            id: "notif-2",
            credentialId: "cred-2",
            ttl: 600,
            messageId: "msg-456",
            messageText: "Verify login",
            customPayload: "{\"data\":\"test\"}",
            challenge: "123456",
            numbersChallenge: "1,2,3",
            loadBalancer: "lb-cookie",
            contextInfo: "{\"ip\":\"192.168.1.1\"}",
            pushType: .challenge,
            createdAt: Date(),
            sentAt: Date(),
            respondedAt: nil,
            additionalData: ["extra": "data"],
            approved: false,
            pending: true
        )
        
        // When
        try await storage.storePushNotification(notification)
        
        // Then
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-2")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.customPayload, "{\"data\":\"test\"}")
        XCTAssertEqual(retrieved?.challenge, "123456")
        XCTAssertEqual(retrieved?.numbersChallenge, "1,2,3")
        XCTAssertEqual(retrieved?.loadBalancer, "lb-cookie")
        XCTAssertEqual(retrieved?.contextInfo, "{\"ip\":\"192.168.1.1\"}")
        XCTAssertNotNil(retrieved?.sentAt)
    }
    
    func testUpdatePushNotification() async throws {
        // Given
        var notification = PushNotification(
            id: "notif-3",
            credentialId: "cred-3",
            ttl: 300,
            messageId: "msg-789",
            messageText: "Login request",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        try await storage.storePushNotification(notification)
        
        // When - mark as approved
        notification.markApproved()
        try await storage.updatePushNotification(notification)
        
        // Then
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-3")
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved!.approved)
        XCTAssertFalse(retrieved!.pending)
        XCTAssertNotNil(retrieved?.respondedAt)
    }
    
    func testGetAllPushNotifications() async throws {
        // Given
        let notification1 = PushNotification(
            id: "notif-4",
            credentialId: "cred-4",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Login 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-5",
            credentialId: "cred-4",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Login 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .challenge,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        // When
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        // Then
        let notifications = try await storage.getAllPushNotifications()
        XCTAssertEqual(notifications.count, 2)
        XCTAssertTrue(notifications.contains { $0.id == "notif-4" })
        XCTAssertTrue(notifications.contains { $0.id == "notif-5" })
    }
    
    func testGetAllPushNotificationsReturnsEmptyWhenNoneStored() async throws {
        // When
        let notifications = try await storage.getAllPushNotifications()
        
        // Then
        XCTAssertTrue(notifications.isEmpty)
    }
    
    func testGetPendingPushNotifications() async throws {
        // Given
        var notification1 = PushNotification(
            id: "notif-6",
            credentialId: "cred-6",
            ttl: 300,
            messageId: "msg-6",
            messageText: "Login 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        var notification2 = PushNotification(
            id: "notif-7",
            credentialId: "cred-6",
            ttl: 300,
            messageId: "msg-7",
            messageText: "Login 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        let totalPending = try await storage.getPendingPushNotifications()
        XCTAssertEqual(totalPending.count, 2)
        
        // Mark one as approved
        notification1.markApproved()
        try await storage.updatePushNotification(notification1)
        
        // When
        let pending = try await storage.getPendingPushNotifications()
        
        // Then
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, "notif-7")
    }
    
    func testRetrievePushNotificationByID() async throws {
        // Given
        let notification = PushNotification(
            id: "notif-8",
            credentialId: "cred-8",
            ttl: 300,
            messageId: "msg-8",
            messageText: "Test",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        try await storage.storePushNotification(notification)
        
        // When
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-8")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "notif-8")
        XCTAssertEqual(retrieved?.messageId, "msg-8")
    }
    
    func testRetrievePushNotificationReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await storage.retrievePushNotification(notificationId: "nonexistent")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testGetNotificationByMessageId() async throws {
        // Given
        let notification = PushNotification(
            id: "notif-9",
            credentialId: "cred-9",
            ttl: 300,
            messageId: "unique-msg-id",
            messageText: "Test",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        try await storage.storePushNotification(notification)
        
        // When
        let retrieved = try await storage.getNotificationByMessageId(messageId: "unique-msg-id")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "notif-9")
        XCTAssertEqual(retrieved?.messageId, "unique-msg-id")
    }
    
    func testGetNotificationByMessageIdReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await storage.getNotificationByMessageId(messageId: "nonexistent-msg")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testRemovePushNotification() async throws {
        // Given
        let notification = PushNotification(
            id: "notif-10",
            credentialId: "cred-10",
            ttl: 300,
            messageId: "msg-10",
            messageText: "Test",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        try await storage.storePushNotification(notification)
        
        // When
        let result = try await storage.removePushNotification(notificationId: "notif-10")
        
        // Then
        XCTAssertTrue(result)
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-10")
        XCTAssertNil(retrieved)
    }
    
    func testRemovePushNotificationReturnsFalseForNonExistent() async throws {
        // When
        let result = try await storage.removePushNotification(notificationId: "nonexistent")
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testRemovePushNotificationsForCredential() async throws {
        // Given
        let notification1 = PushNotification(
            id: "notif-11",
            credentialId: "cred-shared",
            ttl: 300,
            messageId: "msg-11",
            messageText: "Test 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-12",
            credentialId: "cred-shared",
            ttl: 300,
            messageId: "msg-12",
            messageText: "Test 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification3 = PushNotification(
            id: "notif-13",
            credentialId: "cred-other",
            ttl: 300,
            messageId: "msg-13",
            messageText: "Test 3",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        try await storage.storePushNotification(notification3)
        
        // When
        let removedCount = try await storage.removePushNotificationsForCredential(credentialId: "cred-shared")
        
        // Then
        XCTAssertEqual(removedCount, 2)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.credentialId, "cred-other")
    }
    
    func testClearPushNotifications() async throws {
        // Given
        let notification1 = PushNotification(
            id: "notif-14",
            credentialId: "cred-14",
            ttl: 300,
            messageId: "msg-14",
            messageText: "Test 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-15",
            credentialId: "cred-15",
            ttl: 300,
            messageId: "msg-15",
            messageText: "Test 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        // When
        try await storage.clearPushNotifications()
        
        // Then
        let notifications = try await storage.getAllPushNotifications()
        XCTAssertTrue(notifications.isEmpty)
    }
    
    func testClearPushNotificationsDoesNotThrowWhenEmpty() async throws {
        // When/Then - should not throw
        try await storage.clearPushNotifications()
        
        let notifications = try await storage.getAllPushNotifications()
        XCTAssertTrue(notifications.isEmpty)
    }
    
    func testNotificationDateEncoding() async throws {
        // Given
        let createdDate = Date()
        let sentDate = Date().addingTimeInterval(10)
        let respondedDate = Date().addingTimeInterval(20)
        
        let notification = PushNotification(
            id: "notif-16",
            credentialId: "cred-16",
            ttl: 300,
            messageId: "msg-16",
            messageText: "Test",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: createdDate,
            sentAt: sentDate,
            respondedAt: respondedDate,
            additionalData: nil,
            approved: true,
            pending: false
        )
        
        // When
        try await storage.storePushNotification(notification)
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-16")
        
        // Then
        XCTAssertNotNil(retrieved)
        // ISO8601 encoding may lose some precision, so compare within 1 second tolerance
        XCTAssertEqual(retrieved!.createdAt.timeIntervalSince1970, createdDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertNotNil(retrieved!.sentAt)
        XCTAssertNotNil(retrieved!.respondedAt)
    }
    
    func testNotificationPendingAndApprovedState() async throws {
        // Given
        var notification = PushNotification(
            id: "notif-17",
            credentialId: "cred-17",
            ttl: 300,
            messageId: "msg-17",
            messageText: "Test",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        try await storage.storePushNotification(notification)
        
        // When - approve the notification
        notification.markApproved()
        try await storage.updatePushNotification(notification)
        
        // Then
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif-17")
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved!.approved)
        XCTAssertFalse(retrieved!.pending)
        XCTAssertTrue(retrieved!.responded)
    }
    
    // MARK: - Device Token Operations Tests
    
    func testStorePushDeviceToken() async throws {
        // Given
        let token = PushDeviceToken(
            id: "token-1",
            token: "abc123def456",
            createdAt: Date()
        )
        
        // When
        try await storage.storePushDeviceToken(token)
        
        // Then
        let retrieved = try await storage.getCurrentPushDeviceToken()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "token-1")
        XCTAssertEqual(retrieved?.token, "abc123def456")
    }
    
    func testStorePushDeviceTokenOverwritesExisting() async throws {
        // Given
        let token1 = PushDeviceToken(
            id: "token-1",
            token: "old-token",
            createdAt: Date()
        )
        let token2 = PushDeviceToken(
            id: "token-2",
            token: "new-token",
            createdAt: Date().addingTimeInterval(60)
        )
        
        try await storage.storePushDeviceToken(token1)
        
        // When - store a new token
        try await storage.storePushDeviceToken(token2)
        
        // Then - should have the new token, not the old one
        let retrieved = try await storage.getCurrentPushDeviceToken()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "token-2")
        XCTAssertEqual(retrieved?.token, "new-token")
    }
    
    func testGetCurrentPushDeviceTokenReturnsNilWhenNoneStored() async throws {
        // When
        let retrieved = try await storage.getCurrentPushDeviceToken()
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testClearPushDeviceTokens() async throws {
        // Given
        let token = PushDeviceToken(
            id: "token-3",
            token: "abc123",
            createdAt: Date()
        )
        try await storage.storePushDeviceToken(token)
        
        // When
        try await storage.clearPushDeviceTokens()
        
        // Then
        let retrieved = try await storage.getCurrentPushDeviceToken()
        XCTAssertNil(retrieved)
    }
    
    func testClearPushDeviceTokensDoesNotThrowWhenEmpty() async throws {
        // When/Then - should not throw
        try await storage.clearPushDeviceTokens()
        
        let retrieved = try await storage.getCurrentPushDeviceToken()
        XCTAssertNil(retrieved)
    }
    
    func testDeviceTokenDateEncoding() async throws {
        // Given
        let updatedDate = Date()
        let token = PushDeviceToken(
            id: "token-4",
            token: "date-test-token",
            createdAt: updatedDate
        )
        
        // When
        try await storage.storePushDeviceToken(token)
        let retrieved = try await storage.getCurrentPushDeviceToken()
        
        // Then
        XCTAssertNotNil(retrieved)
        // ISO8601 encoding may lose some precision, so compare within 1 second tolerance
        XCTAssertEqual(retrieved!.createdAt.timeIntervalSince1970, updatedDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testDeviceTokenPersistence() async throws {
        // Given
        let token = PushDeviceToken(
            id: "token-5",
            token: "persistence-test",
            createdAt: Date()
        )
        
        // When
        try await storage.storePushDeviceToken(token)
        
        // Create a new storage instance to test persistence
        let newStorage = PushKeychainStorage(
            credentialService: "com.pingidentity.push.test.credentials",
            notificationService: "com.pingidentity.push.test.notifications",
            tokenService: "com.pingidentity.push.test.tokens"
        )
        
        let retrieved = try await newStorage.getCurrentPushDeviceToken()
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "token-5")
        XCTAssertEqual(retrieved?.token, "persistence-test")
    }
    
    // MARK: - Cleanup Operations Tests
    
    func testCountPushNotificationsWithoutCredentialFilter() async throws {
        // Given
        let notification1 = PushNotification(
            id: "notif-count-1",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Test 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-count-2",
            credentialId: "cred-2",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Test 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        // When
        let count = try await storage.countPushNotifications(credentialId: nil)
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func testCountPushNotificationsWithCredentialFilter() async throws {
        // Given
        let notification1 = PushNotification(
            id: "notif-filter-1",
            credentialId: "cred-shared",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Test 1",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-filter-2",
            credentialId: "cred-shared",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Test 2",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification3 = PushNotification(
            id: "notif-filter-3",
            credentialId: "cred-other",
            ttl: 300,
            messageId: "msg-3",
            messageText: "Test 3",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        try await storage.storePushNotification(notification3)
        
        // When
        let count = try await storage.countPushNotifications(credentialId: "cred-shared")
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func testGetOldestPushNotifications() async throws {
        // Given - create notifications with different timestamps
        let now = Date()
        let notification1 = PushNotification(
            id: "notif-old-1",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Oldest",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-3600), // 1 hour ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-old-2",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Middle",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-1800), // 30 minutes ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification3 = PushNotification(
            id: "notif-old-3",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-3",
            messageText: "Newest",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-900), // 15 minutes ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        try await storage.storePushNotification(notification3)
        
        // When - get 2 oldest
        let oldest = try await storage.getOldestPushNotifications(limit: 2, credentialId: nil)
        
        // Then
        XCTAssertEqual(oldest.count, 2)
        XCTAssertEqual(oldest[0].id, "notif-old-1")
        XCTAssertEqual(oldest[1].id, "notif-old-2")
    }
    
    func testGetOldestPushNotificationsWithCredentialFilter() async throws {
        // Given
        let now = Date()
        let notification1 = PushNotification(
            id: "notif-cred-1",
            credentialId: "cred-target",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Old for target",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-3600),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let notification2 = PushNotification(
            id: "notif-cred-2",
            credentialId: "cred-other",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Older for other",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-7200), // Even older
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        // When - get oldest for specific credential
        let oldest = try await storage.getOldestPushNotifications(limit: 10, credentialId: "cred-target")
        
        // Then - should only return notifications for target credential
        XCTAssertEqual(oldest.count, 1)
        XCTAssertEqual(oldest[0].id, "notif-cred-1")
    }
    
    func testPurgePushNotificationsByAge() async throws {
        // Given
        let now = Date()
        let oldNotification = PushNotification(
            id: "notif-old",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-old",
            messageText: "Old",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60), // 31 days ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let recentNotification = PushNotification(
            id: "notif-recent",
            credentialId: "cred-1",
            ttl: 300,
            messageId: "msg-recent",
            messageText: "Recent",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(oldNotification)
        try await storage.storePushNotification(recentNotification)
        
        // When - purge notifications older than 30 days
        let purgedCount = try await storage.purgePushNotificationsByAge(maxAgeDays: 30, credentialId: nil)
        
        // Then
        XCTAssertEqual(purgedCount, 1)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, "notif-recent")
    }
    
    func testPurgePushNotificationsByAgeWithCredentialFilter() async throws {
        // Given
        let now = Date()
        let oldNotification1 = PushNotification(
            id: "notif-old-1",
            credentialId: "cred-target",
            ttl: 300,
            messageId: "msg-1",
            messageText: "Old for target",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60), // 31 days ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        let oldNotification2 = PushNotification(
            id: "notif-old-2",
            credentialId: "cred-other",
            ttl: 300,
            messageId: "msg-2",
            messageText: "Old for other",
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60), // 31 days ago
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
        
        try await storage.storePushNotification(oldNotification1)
        try await storage.storePushNotification(oldNotification2)
        
        // When - purge only for target credential
        let purgedCount = try await storage.purgePushNotificationsByAge(maxAgeDays: 30, credentialId: "cred-target")
        
        // Then - should only purge target credential's notification
        XCTAssertEqual(purgedCount, 1)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].credentialId, "cred-other")
    }
    
    func testPurgePushNotificationsByCount() async throws {
        // Given - create 5 notifications
        let now = Date()
        for i in 1...5 {
            let notification = PushNotification(
                id: "notif-count-\(i)",
                credentialId: "cred-1",
                ttl: 300,
                messageId: "msg-\(i)",
                messageText: "Test \(i)",
                customPayload: nil,
                challenge: nil,
                numbersChallenge: nil,
                loadBalancer: nil,
                contextInfo: nil,
                pushType: .default,
                createdAt: now.addingTimeInterval(Double(-i * 3600)), // Oldest has highest i
                sentAt: nil,
                respondedAt: nil,
                additionalData: nil,
                approved: false,
                pending: true
            )
            try await storage.storePushNotification(notification)
        }
        
        // When - keep only 3 most recent
        let purgedCount = try await storage.purgePushNotificationsByCount(maxCount: 3, credentialId: nil)
        
        // Then - should purge 2 oldest
        XCTAssertEqual(purgedCount, 2)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 3)
        
        // Verify the 2 oldest were removed
        XCTAssertFalse(remaining.contains { $0.id == "notif-count-5" })
        XCTAssertFalse(remaining.contains { $0.id == "notif-count-4" })
    }
    
    func testPurgePushNotificationsByCountWithCredentialFilter() async throws {
        // Given
        let now = Date()
        // Create 3 notifications for target credential
        for i in 1...3 {
            let notification = PushNotification(
                id: "notif-target-\(i)",
                credentialId: "cred-target",
                ttl: 300,
                messageId: "msg-\(i)",
                messageText: "Target \(i)",
                customPayload: nil,
                challenge: nil,
                numbersChallenge: nil,
                loadBalancer: nil,
                contextInfo: nil,
                pushType: .default,
                createdAt: now.addingTimeInterval(Double(-i * 3600)),
                sentAt: nil,
                respondedAt: nil,
                additionalData: nil,
                approved: false,
                pending: true
            )
            try await storage.storePushNotification(notification)
        }
        
        // Create 2 notifications for other credential
        for i in 1...2 {
            let notification = PushNotification(
                id: "notif-other-\(i)",
                credentialId: "cred-other",
                ttl: 300,
                messageId: "msg-other-\(i)",
                messageText: "Other \(i)",
                customPayload: nil,
                challenge: nil,
                numbersChallenge: nil,
                loadBalancer: nil,
                contextInfo: nil,
                pushType: .default,
                createdAt: now.addingTimeInterval(Double(-i * 3600)),
                sentAt: nil,
                respondedAt: nil,
                additionalData: nil,
                approved: false,
                pending: true
            )
            try await storage.storePushNotification(notification)
        }
        
        // When - purge target credential to keep only 1
        let purgedCount = try await storage.purgePushNotificationsByCount(maxCount: 1, credentialId: "cred-target")
        
        // Then - should purge 2 from target credential
        XCTAssertEqual(purgedCount, 2)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 3) // 1 target + 2 other
        
        let targetRemaining = remaining.filter { $0.credentialId == "cred-target" }
        XCTAssertEqual(targetRemaining.count, 1)
        XCTAssertEqual(targetRemaining[0].id, "notif-target-1") // Most recent
    }
    
    func testPurgePushNotificationsByCountNoPurgeNeeded() async throws {
        // Given - only 2 notifications
        let now = Date()
        for i in 1...2 {
            let notification = PushNotification(
                id: "notif-\(i)",
                credentialId: "cred-1",
                ttl: 300,
                messageId: "msg-\(i)",
                messageText: "Test \(i)",
                customPayload: nil,
                challenge: nil,
                numbersChallenge: nil,
                loadBalancer: nil,
                contextInfo: nil,
                pushType: .default,
                createdAt: now.addingTimeInterval(Double(-i * 3600)),
                sentAt: nil,
                respondedAt: nil,
                additionalData: nil,
                approved: false,
                pending: true
            )
            try await storage.storePushNotification(notification)
        }
        
        // When - try to keep 5 (more than we have)
        let purgedCount = try await storage.purgePushNotificationsByCount(maxCount: 5, credentialId: nil)
        
        // Then - should not purge anything
        XCTAssertEqual(purgedCount, 0)
        
        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 2)
    }
}
