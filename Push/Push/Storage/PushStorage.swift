//
//  PushStorage.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol for Push-specific storage operations.
/// Extends the base storage capabilities with Push-specific functionality.
///
/// Implementations of this protocol must be thread-safe and handle concurrent access properly.
public protocol PushStorage: Sendable {

    // MARK: - Credential Operations

    /// Store a push credential.
    /// - Parameter credential: The Push credential to be stored.
    /// - Throws: `PushStorageError.storageFailure` if the credential cannot be stored.
    /// - Throws: `PushStorageError.duplicateCredential` if a credential with the same ID already exists.
    func storePushCredential(_ credential: PushCredential) async throws

    /// Retrieve all stored push credentials.
    /// - Returns: A list of all Push credentials.
    /// - Throws: `PushStorageError.storageFailure` if the credentials cannot be retrieved.
    func getAllPushCredentials() async throws -> [PushCredential]

    /// Retrieve a specific push credential by ID.
    /// - Parameter credentialId: The ID of the credential to retrieve.
    /// - Returns: The Push credential, or nil if not found.
    /// - Throws: `PushStorageError.storageFailure` if the credential cannot be retrieved.
    func retrievePushCredential(credentialId: String) async throws -> PushCredential?

    /// Remove a push credential by its ID.
    /// - Parameter credentialId: The ID of the credential to remove.
    /// - Returns: true if the credential was successfully removed, false if it didn't exist.
    /// - Throws: `PushStorageError.storageFailure` if the credential cannot be removed.
    func removePushCredential(credentialId: String) async throws -> Bool

    /// Clear all Push credentials from the storage.
    /// - Throws: `PushStorageError.storageFailure` if the credentials cannot be cleared.
    func clearPushCredentials() async throws

    // MARK: - Notification Operations

    /// Store a push notification.
    /// - Parameter notification: The Push notification to be stored.
    /// - Throws: `PushStorageError.storageFailure` if the notification cannot be stored.
    func storePushNotification(_ notification: PushNotification) async throws

    /// Update a push notification.
    /// - Parameter notification: The Push notification to update.
    /// - Throws: `PushStorageError.storageFailure` if the notification cannot be updated.
    func updatePushNotification(_ notification: PushNotification) async throws

    /// Retrieve all stored push notifications.
    /// - Returns: A list of all Push notifications.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be retrieved.
    func getAllPushNotifications() async throws -> [PushNotification]

    /// Retrieve all pending push notifications.
    /// - Returns: A list of pending Push notifications.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be retrieved.
    func getPendingPushNotifications() async throws -> [PushNotification]

    /// Retrieve a specific push notification by ID.
    /// - Parameter notificationId: The ID of the notification to retrieve.
    /// - Returns: The Push notification, or nil if not found.
    /// - Throws: `PushStorageError.storageFailure` if the notification cannot be retrieved.
    func retrievePushNotification(notificationId: String) async throws -> PushNotification?

    /// Retrieve a push notification by message ID.
    /// - Parameter messageId: The message ID of the notification to retrieve.
    /// - Returns: The Push notification, or nil if not found.
    /// - Throws: `PushStorageError.storageFailure` if the notification cannot be retrieved.
    func getNotificationByMessageId(messageId: String) async throws -> PushNotification?

    /// Remove a push notification by its ID.
    /// - Parameter notificationId: The ID of the notification to remove.
    /// - Returns: true if the notification was successfully removed, false if it didn't exist.
    /// - Throws: `PushStorageError.storageFailure` if the notification cannot be removed.
    func removePushNotification(notificationId: String) async throws -> Bool

    /// Remove all push notifications associated with a credential.
    /// - Parameter credentialId: The ID of the credential.
    /// - Returns: The number of notifications removed.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be removed.
    func removePushNotificationsForCredential(credentialId: String) async throws -> Int

    /// Clear all Push notifications from the storage.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be cleared.
    func clearPushNotifications() async throws

    // MARK: - Device Token Operations

    /// Store a push device token.
    /// - Parameter token: The Push device token to be stored.
    /// - Throws: `PushStorageError.storageFailure` if the token cannot be stored.
    func storePushDeviceToken(_ token: PushDeviceToken) async throws

    /// Retrieve the current push device token.
    /// - Returns: The current Push device token, or nil if not found.
    /// - Throws: `PushStorageError.storageFailure` if the token cannot be retrieved.
    func getCurrentPushDeviceToken() async throws -> PushDeviceToken?

    /// Clear all Push device tokens from the storage.
    /// - Throws: `PushStorageError.storageFailure` if the tokens cannot be cleared.
    func clearPushDeviceTokens() async throws

    // MARK: - Notification Cleanup Operations

    /// Count the number of push notifications.
    /// - Parameter credentialId: Optional ID of a specific credential to count notifications for.
    /// - Returns: The count of push notifications.
    /// - Throws: `PushStorageError.storageFailure` if the count cannot be retrieved.
    func countPushNotifications(credentialId: String?) async throws -> Int

    /// Retrieve the oldest push notifications.
    /// - Parameters:
    ///   - limit: The maximum number of notifications to retrieve.
    ///   - credentialId: Optional ID of a specific credential to retrieve notifications for.
    /// - Returns: A list of the oldest push notifications.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be retrieved.
    func getOldestPushNotifications(limit: Int, credentialId: String?) async throws -> [PushNotification]

    /// Purge push notifications by age.
    /// - Parameters:
    ///   - maxAgeDays: The maximum age in days for notifications to keep.
    ///   - credentialId: Optional ID of a specific credential to purge notifications for.
    /// - Returns: The number of notifications removed.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be purged.
    func purgePushNotificationsByAge(maxAgeDays: Int, credentialId: String?) async throws -> Int

    /// Purge push notifications by count (removes oldest notifications when count exceeds the limit).
    /// - Parameters:
    ///   - maxCount: The maximum number of notifications to keep.
    ///   - credentialId: Optional ID of a specific credential to purge notifications for.
    /// - Returns: The number of notifications removed.
    /// - Throws: `PushStorageError.storageFailure` if the notifications cannot be purged.
    func purgePushNotificationsByCount(maxCount: Int, credentialId: String?) async throws -> Int
}
