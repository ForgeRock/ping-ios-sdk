//
//  TestInMemoryPushStorage.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
@testable import PingPush

/// Simple in-memory storage used for unit testing.
///
/// The production implementation relies on the Keychain which is slower and harder to
/// control in tests. This in-memory actor provides deterministic behaviour for tests that
/// exercise higher-level utilities such as `PushDeviceTokenManager` and
/// `NotificationCleanupManager`.
actor TestInMemoryPushStorage: PushStorage {

    private var credentials: [String: PushCredential] = [:]
    private var notifications: [String: PushNotification] = [:]
    private var deviceToken: PushDeviceToken?

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
        credentials.removeValue(forKey: credentialId) != nil
    }

    func clearPushCredentials() async throws {
        credentials.removeAll()
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
        notifications.removeValue(forKey: notificationId) != nil
    }

    func removePushNotificationsForCredential(credentialId: String) async throws -> Int {
        let toRemove = notifications.values.filter { $0.credentialId == credentialId }
        toRemove.forEach { notifications.removeValue(forKey: $0.id) }
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

    // MARK: - Cleanup Operations

    func countPushNotifications(credentialId: String?) async throws -> Int {
        filteredNotifications(for: credentialId).count
    }

    func getOldestPushNotifications(limit: Int, credentialId: String?) async throws -> [PushNotification] {
        let sorted = sortedNotifications(for: credentialId)
        guard limit > 0 else { return [] }
        return Array(sorted.prefix(limit))
    }

    func purgePushNotificationsByAge(maxAgeDays: Int, credentialId: String?) async throws -> Int {
        let threshold = Date().addingTimeInterval(-Double(max(maxAgeDays, 0)) * 24 * 60 * 60)
        let candidates = filteredNotifications(for: credentialId)
        let expired = candidates.filter { $0.createdAt < threshold }
        expired.forEach { notifications.removeValue(forKey: $0.id) }
        return expired.count
    }

    func purgePushNotificationsByCount(maxCount: Int, credentialId: String?) async throws -> Int {
        let candidates = filteredNotifications(for: credentialId)
        let limit = max(maxCount, 0)
        guard candidates.count > limit else { return 0 }

        let sorted = sortedNotifications(for: credentialId)
        let excess = sorted.prefix(candidates.count - limit)
        excess.forEach { notifications.removeValue(forKey: $0.id) }
        return excess.count
    }

    // MARK: - Helpers

    private func filteredNotifications(for credentialId: String?) -> [PushNotification] {
        notifications.values.filter { credentialId == nil || $0.credentialId == credentialId }
    }

    private func sortedNotifications(for credentialId: String?) -> [PushNotification] {
        filteredNotifications(for: credentialId).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
