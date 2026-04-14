//
//  MockPushStorage.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingPush

/// In-memory mock implementation of `PushStorage` for use in unit tests.
actor MockPushStorage: PushStorage {

    private var credentials: [String: PushCredential] = [:]
    private var notifications: [String: PushNotification] = [:]
    private var deviceToken: PushDeviceToken? = nil

    // MARK: - Test Helpers

    /// Returns all credentials currently stored (for assertions).
    func getAllCredentials() -> [PushCredential] {
        Array(credentials.values)
    }

    /// Pre-populates the storage with a credential (for duplicate-detection tests).
    func seedCredential(_ credential: PushCredential) {
        credentials[credential.id] = credential
    }

    // MARK: - Credential Operations

    func storePushCredential(_ credential: PushCredential) async throws {
        credentials[credential.id] = credential
    }

    func getAllPushCredentials() async throws -> [PushCredential] {
        Array(credentials.values)
    }

    func retrievePushCredential(credentialId: String) async throws -> PushCredential? {
        credentials[credentialId]
    }

    func removePushCredential(credentialId: String) async throws -> Bool {
        let existed = credentials[credentialId] != nil
        credentials.removeValue(forKey: credentialId)
        return existed
    }

    func clearPushCredentials() async throws {
        credentials.removeAll()
    }

    func getCredentialByIssuerAndAccount(issuer: String, accountName: String) async throws -> PushCredential? {
        credentials.values.first { $0.issuer == issuer && $0.accountName == accountName }
    }

    // MARK: - Notification Operations

    func storePushNotification(_ notification: PushNotification) async throws {
        notifications[notification.id] = notification
    }

    func updatePushNotification(_ notification: PushNotification) async throws {
        notifications[notification.id] = notification
    }

    func getAllPushNotifications() async throws -> [PushNotification] {
        Array(notifications.values)
    }

    func getPendingPushNotifications() async throws -> [PushNotification] {
        notifications.values.filter { $0.pending }
    }

    func retrievePushNotification(notificationId: String) async throws -> PushNotification? {
        notifications[notificationId]
    }

    func getNotificationByMessageId(messageId: String) async throws -> PushNotification? {
        notifications.values.first { $0.messageId == messageId }
    }

    func removePushNotification(notificationId: String) async throws -> Bool {
        let existed = notifications[notificationId] != nil
        notifications.removeValue(forKey: notificationId)
        return existed
    }

    func removePushNotificationsForCredential(credentialId: String) async throws -> Int {
        let toRemove = notifications.values.filter { $0.credentialId == credentialId }
        for n in toRemove { notifications.removeValue(forKey: n.id) }
        return toRemove.count
    }

    func clearPushNotifications() async throws {
        notifications.removeAll()
    }

    // MARK: - Device Token Operations

    func storePushDeviceToken(_ token: PushDeviceToken) async throws {
        deviceToken = token
    }

    func getCurrentPushDeviceToken() async throws -> PushDeviceToken? {
        deviceToken
    }

    func clearPushDeviceTokens() async throws {
        deviceToken = nil
    }

    // MARK: - Notification Cleanup Operations

    func countPushNotifications(credentialId: String?) async throws -> Int {
        if let id = credentialId {
            return notifications.values.filter { $0.credentialId == id }.count
        }
        return notifications.count
    }

    func getOldestPushNotifications(limit: Int, credentialId: String?) async throws -> [PushNotification] {
        let filtered: [PushNotification]
        if let id = credentialId {
            filtered = notifications.values.filter { $0.credentialId == id }
        } else {
            filtered = Array(notifications.values)
        }
        return Array(filtered.sorted { $0.createdAt < $1.createdAt }.prefix(limit))
    }

    func purgePushNotificationsByAge(maxAgeDays: Int, credentialId: String?) async throws -> Int {
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 86_400)
        let toRemove = notifications.values.filter {
            $0.createdAt < cutoff && (credentialId == nil || $0.credentialId == credentialId)
        }
        for n in toRemove { notifications.removeValue(forKey: n.id) }
        return toRemove.count
    }

    func purgePushNotificationsByCount(maxCount: Int, credentialId: String?) async throws -> Int {
        let filtered: [PushNotification]
        if let id = credentialId {
            filtered = notifications.values.filter { $0.credentialId == id }
        } else {
            filtered = Array(notifications.values)
        }
        let sorted = filtered.sorted { $0.createdAt < $1.createdAt }
        let overflow = max(0, sorted.count - maxCount)
        let toRemove = sorted.prefix(overflow)
        for n in toRemove { notifications.removeValue(forKey: n.id) }
        return toRemove.count
    }
}
