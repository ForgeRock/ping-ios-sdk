//
//  PushKeychainStorageIntegrationTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

/// Integration tests for PushKeychainStorage.
/// These tests verify end-to-end scenarios and interactions between different storage operations.
final class PushKeychainStorageIntegrationTests: XCTestCase {
    
    var storage: PushKeychainStorage!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create storage with unique service identifiers for integration tests
        storage = PushKeychainStorage(
            credentialService: "com.pingidentity.push.integration.credentials",
            notificationService: "com.pingidentity.push.integration.notifications",
            tokenService: "com.pingidentity.push.integration.tokens"
        )
        
        // Clean up any existing data
        try await storage.clearPushCredentials()
        try await storage.clearPushNotifications()
        try await storage.clearPushDeviceTokens()
    }
    
    override func tearDown() async throws {
        // Clean up after each test
        try await storage.clearPushCredentials()
        try await storage.clearPushNotifications()
        try await storage.clearPushDeviceTokens()
        
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - End-to-End Credential Lifecycle Tests
    
    func testCompleteCredentialLifecycle() async throws {
        // Given: A complete credential lifecycle scenario
        let credential1 = PushCredential(
            id: "cred1",
            issuer: "Test Issuer 1",
            accountName: "user1@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123"
        )
        
        let credential2 = PushCredential(
            id: "cred2",
            issuer: "Test Issuer 2",
            accountName: "user2@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret456"
        )
        
        // When: Store multiple credentials
        try await storage.storePushCredential(credential1)
        try await storage.storePushCredential(credential2)
        
        // Then: Both credentials are stored
        let allCredentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(allCredentials.count, 2)
        XCTAssertTrue(allCredentials.contains { $0.id == "cred1" })
        XCTAssertTrue(allCredentials.contains { $0.id == "cred2" })
        
        // When: Retrieve specific credential
        let retrieved = try await storage.retrievePushCredential(credentialId: "cred1")
        
        // Then: Correct credential is retrieved
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "cred1")
        XCTAssertEqual(retrieved?.accountName, "user1@example.com")
        
        // When: Remove one credential
        let removed = try await storage.removePushCredential(credentialId: "cred1")
        
        // Then: Credential is removed and count is updated
        XCTAssertTrue(removed)
        let remainingCredentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(remainingCredentials.count, 1)
        XCTAssertEqual(remainingCredentials.first?.id, "cred2")
        
        // When: Clear all credentials
        try await storage.clearPushCredentials()
        
        // Then: No credentials remain
        let finalCredentials = try await storage.getAllPushCredentials()
        XCTAssertTrue(finalCredentials.isEmpty)
    }
    
    // MARK: - End-to-End Notification Flow Tests
    
    func testCompleteNotificationFlowWithCredential() async throws {
        // Given: A credential and multiple notifications
        let credential = PushCredential(
            id: "cred1",
            issuer: "Test Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123"
        )
        
        try await storage.storePushCredential(credential)
        
        let notification1 = PushNotification(
            id: "notif1",
            credentialId: "cred1",
            ttl: 300,
            messageId: "msg1",
            pushType: .default
        )
        
        let notification2 = PushNotification(
            id: "notif2",
            credentialId: "cred1",
            ttl: 300,
            messageId: "msg2",
            pushType: .challenge
        )
        
        // When: Store notifications
        try await storage.storePushNotification(notification1)
        try await storage.storePushNotification(notification2)
        
        // Then: Notifications are stored and retrievable
        let allNotifications = try await storage.getAllPushNotifications()
        XCTAssertEqual(allNotifications.count, 2)
        
        // When: Update notification status
        var updatedNotification = notification1
        updatedNotification.markApproved()
        try await storage.updatePushNotification(updatedNotification)
        
        // Then: Updated notification reflects changes
        let retrieved = try await storage.retrievePushNotification(notificationId: "notif1")
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved!.approved)
        XCTAssertFalse(retrieved!.pending)
        
        // When: Get pending notifications
        let pending = try await storage.getPendingPushNotifications()
        
        // Then: Only pending notification is returned
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, "notif2")
        
        // When: Remove notifications for credential
        let removedCount = try await storage.removePushNotificationsForCredential(credentialId: "cred1")
        
        // Then: All credential notifications are removed
        XCTAssertEqual(removedCount, 2)
        let remainingNotifications = try await storage.getAllPushNotifications()
        XCTAssertTrue(remainingNotifications.isEmpty)
    }
    
    func testNotificationCleanupIntegration() async throws {
        // Given: A credential with many notifications
        let credential = PushCredential(
            id: "cred1",
            issuer: "Test Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123"
        )
        
        try await storage.storePushCredential(credential)
        
        // Create 150 notifications
        for i in 0..<150 {
            let notification = PushNotification(
                id: "notif\(i)",
                credentialId: "cred1",
                ttl: 300,
                messageId: "msg\(i)",
                pushType: .default,
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 60)) // Spread over time
            )
            try await storage.storePushNotification(notification)
        }
        
        // When: Count notifications
        let totalCount = try await storage.countPushNotifications(credentialId: nil)
        
        // Then: All notifications are counted
        XCTAssertEqual(totalCount, 150)
        
        // When: Get oldest 50 notifications
        let oldest = try await storage.getOldestPushNotifications(limit: 50, credentialId: nil)
        
        // Then: Oldest 50 are returned in order
        XCTAssertEqual(oldest.count, 50)
        XCTAssertTrue(oldest[0].createdAt < oldest[49].createdAt)
        
        // When: Purge by count (keep only 100)
        let purgedByCount = try await storage.purgePushNotificationsByCount(maxCount: 100, credentialId: nil)
        
        // Then: 50 oldest are removed
        XCTAssertEqual(purgedByCount, 50)
        let afterCountPurge = try await storage.countPushNotifications(credentialId: nil)
        XCTAssertEqual(afterCountPurge, 100)
        
        // When: Purge by age (remove older than 1 hour)
        let purgedByAge = try await storage.purgePushNotificationsByAge(maxAgeDays: 0, credentialId: nil) // 0 days = remove old ones
        
        // Then: Old notifications are removed
        XCTAssertGreaterThan(purgedByAge, 0)
    }
    
    // MARK: - Device Token Integration Tests
    
    func testDeviceTokenWithCredentialFlow() async throws {
        // Given: A credential and device token
        let credential = PushCredential(
            id: "cred1",
            issuer: "Test Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123"
        )
        
        let deviceToken = PushDeviceToken(
            token: "abc123def456"
        )
        
        // When: Store credential and token
        try await storage.storePushCredential(credential)
        try await storage.storePushDeviceToken(deviceToken)
        
        // Then: Both are retrievable
        let retrievedCredential = try await storage.retrievePushCredential(credentialId: "cred1")
        let retrievedToken = try await storage.getCurrentPushDeviceToken()
        
        XCTAssertNotNil(retrievedCredential)
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken?.token, "abc123def456")
        
        // When: Update device token
        let newToken = PushDeviceToken(token: "new789token")
        try await storage.storePushDeviceToken(newToken)
        
        // Then: New token replaces old one
        let updatedToken = try await storage.getCurrentPushDeviceToken()
        XCTAssertEqual(updatedToken?.token, "new789token")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentCredentialOperations() async throws {
        // Given: Multiple concurrent operations
        let credentials = (0..<10).map { index in
            PushCredential(
                id: "cred\(index)",
                issuer: "Test Issuer \(index)",
                accountName: "user\(index)@example.com",
                serverEndpoint: "https://api.example.com/push",
                sharedSecret: "secret\(index)"
            )
        }
        
        // When: Store credentials concurrently
        try await withThrowingTaskGroup(of: Void.self) { [storage = storage!] group in
            for credential in credentials {
                group.addTask {
                    try await storage.storePushCredential(credential)
                }
            }
            try await group.waitForAll()
        }
        
        // Then: All credentials are stored
        let allCredentials = try await storage.getAllPushCredentials()
        XCTAssertEqual(allCredentials.count, 10)
        
        // When: Retrieve credentials concurrently
        let retrievedCredentials = try await withThrowingTaskGroup(of: PushCredential?.self) { [storage = storage!] group in
            for index in 0..<10 {
                group.addTask {
                    try await storage.retrievePushCredential(credentialId: "cred\(index)")
                }
            }
            
            var results: [PushCredential?] = []
            for try await credential in group {
                results.append(credential)
            }
            return results
        }
        
        // Then: All retrievals succeed
        XCTAssertEqual(retrievedCredentials.compactMap { $0 }.count, 10)
    }
    
    func testConcurrentNotificationOperations() async throws {
        // Given: A credential and multiple concurrent notification operations
        let credential = PushCredential(
            id: "cred1",
            issuer: "Test Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123"
        )
        
        try await storage.storePushCredential(credential)
        
        let notifications = (0..<20).map { index in
            PushNotification(
                id: "notif\(index)",
                credentialId: "cred1",
                ttl: 300,
                messageId: "msg\(index)",
                pushType: index % 2 == 0 ? .default : .challenge
            )
        }
        
        // When: Store notifications concurrently
        try await withThrowingTaskGroup(of: Void.self) { [storage = storage!] group in
            for notification in notifications {
                group.addTask {
                    try await storage.storePushNotification(notification)
                }
            }
            try await group.waitForAll()
        }
        
        // Then: All notifications are stored
        let allNotifications = try await storage.getAllPushNotifications()
        XCTAssertEqual(allNotifications.count, 20)
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryFromNonExistentCredential() async throws {
        // Given: No credentials in storage
        
        // When: Try to retrieve non-existent credential
        let retrieved = try await storage.retrievePushCredential(credentialId: "nonexistent")
        
        // Then: Returns nil without error
        XCTAssertNil(retrieved)
        
        // When: Try to remove non-existent credential
        let removed = try await storage.removePushCredential(credentialId: "nonexistent")
        
        // Then: Returns false without error
        XCTAssertFalse(removed)
    }
    
    func testRecoveryFromInvalidNotificationOperations() async throws {
        // Given: No notifications in storage
        
        // When: Try to retrieve non-existent notification
        let retrieved = try await storage.retrievePushNotification(notificationId: "nonexistent")
        
        // Then: Returns nil without error
        XCTAssertNil(retrieved)
        
        // When: Try to get notification by non-existent message ID
        let byMessageId = try await storage.getNotificationByMessageId(messageId: "nonexistent")
        
        // Then: Returns nil without error
        XCTAssertNil(byMessageId)
        
        // When: Try to remove notifications for non-existent credential
        let removedCount = try await storage.removePushNotificationsForCredential(credentialId: "nonexistent")
        
        // Then: Returns 0 without error
        XCTAssertEqual(removedCount, 0)
    }
    
    // MARK: - Cross-Operation Integration Tests
    
    func testMultipleCredentialsWithNotifications() async throws {
        // Given: Multiple credentials each with their own notifications
        let credential1 = PushCredential(
            id: "cred1",
            issuer: "Issuer 1",
            accountName: "user1@example.com",
            serverEndpoint: "https://api1.example.com/push",
            sharedSecret: "secret1"
        )
        
        let credential2 = PushCredential(
            id: "cred2",
            issuer: "Issuer 2",
            accountName: "user2@example.com",
            serverEndpoint: "https://api2.example.com/push",
            sharedSecret: "secret2"
        )
        
        try await storage.storePushCredential(credential1)
        try await storage.storePushCredential(credential2)
        
        // Store notifications for each credential
        for i in 0..<5 {
            let notif1 = PushNotification(
                id: "cred1-notif\(i)",
                credentialId: "cred1",
                ttl: 300,
                messageId: "cred1-msg\(i)",
                pushType: .default
            )
            try await storage.storePushNotification(notif1)
            
            let notif2 = PushNotification(
                id: "cred2-notif\(i)",
                credentialId: "cred2",
                ttl: 300,
                messageId: "cred2-msg\(i)",
                pushType: .challenge
            )
            try await storage.storePushNotification(notif2)
        }
        
        // When: Count notifications per credential
        let cred1Count = try await storage.countPushNotifications(credentialId: "cred1")
        let cred2Count = try await storage.countPushNotifications(credentialId: "cred2")
        let totalCount = try await storage.countPushNotifications(credentialId: nil)
        
        // Then: Counts are correct
        XCTAssertEqual(cred1Count, 5)
        XCTAssertEqual(cred2Count, 5)
        XCTAssertEqual(totalCount, 10)
        
        // When: Remove notifications for one credential
        let removedCount = try await storage.removePushNotificationsForCredential(credentialId: "cred1")
        
        // Then: Only that credential's notifications are removed
        XCTAssertEqual(removedCount, 5)
        let remainingCount = try await storage.countPushNotifications(credentialId: nil)
        XCTAssertEqual(remainingCount, 5)
        
        let cred2Remaining = try await storage.countPushNotifications(credentialId: "cred2")
        XCTAssertEqual(cred2Remaining, 5)
    }
    
    func testDateEncodingConsistencyAcrossOperations() async throws {
        // Given: Items with specific dates
        let specificDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        
        let credential = PushCredential(
            id: "cred1",
            issuer: "Test Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://api.example.com/push",
            sharedSecret: "secret123",
            createdAt: specificDate
        )
        
        let notification = PushNotification(
            id: "notif1",
            credentialId: "cred1",
            ttl: 300,
            messageId: "msg1",
            pushType: .default,
            createdAt: specificDate,
            sentAt: specificDate.addingTimeInterval(10)
        )
        
        let deviceToken = PushDeviceToken(
            token: "abc123",
            createdAt: specificDate
        )
        
        // When: Store and retrieve all items
        try await storage.storePushCredential(credential)
        try await storage.storePushNotification(notification)
        try await storage.storePushDeviceToken(deviceToken)
        
        let retrievedCredential = try await storage.retrievePushCredential(credentialId: "cred1")
        let retrievedNotification = try await storage.retrievePushNotification(notificationId: "notif1")
        let retrievedToken = try await storage.getCurrentPushDeviceToken()
        
        // Then: Dates are preserved correctly
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential!.createdAt.timeIntervalSince1970, specificDate.timeIntervalSince1970, accuracy: 0.001)
        
        XCTAssertNotNil(retrievedNotification)
        XCTAssertEqual(retrievedNotification!.createdAt.timeIntervalSince1970, specificDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertNotNil(retrievedNotification!.sentAt)
        XCTAssertEqual(retrievedNotification!.sentAt!.timeIntervalSince1970, specificDate.addingTimeInterval(10).timeIntervalSince1970, accuracy: 0.001)
        
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken!.createdAt.timeIntervalSince1970, specificDate.timeIntervalSince1970, accuracy: 0.001)
    }
}
