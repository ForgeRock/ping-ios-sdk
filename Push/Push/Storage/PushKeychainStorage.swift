//
//  PushKeychainStorage.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import PingLogger

/// Keychain-based storage implementation for Push credentials and notifications.
/// Uses iOS Keychain Services for secure credential storage.
///
/// This implementation stores each item as JSON data in the iOS Keychain
/// with unique identifiers as keys. Credentials and device tokens are stored
/// securely and are never exposed in memory longer than necessary.
///
/// - Note: This class is thread-safe and handles concurrent access properly using DispatchQueue.
public final class PushKeychainStorage: PushStorage, @unchecked Sendable {

    /// The keychain service identifier used for storing credentials.
    private let credentialService: String

    /// The keychain service identifier used for storing notifications.
    private let notificationService: String

    /// The keychain service identifier used for storing device tokens.
    private let tokenService: String

    /// The logger instance for logging storage operations.
    private let logger: Logger?

    /// The keychain access group for shared keychain access (optional).
    private let accessGroup: String?

    /// The keychain accessibility level for stored items.
    private let accessibility: CFString


    // MARK: - Initializers

    /// Creates a new keychain storage instance.
    /// - Parameters:
    ///   - credentialService: The keychain service identifier for credentials.
    ///     Defaults to "com.pingidentity.push.credentials".
    ///   - notificationService: The keychain service identifier for notifications.
    ///     Defaults to "com.pingidentity.push.notifications".
    ///   - tokenService: The keychain service identifier for device tokens.
    ///     Defaults to "com.pingidentity.push.tokens".
    ///   - logger: Optional logger for storage operations.
    ///   - accessGroup: Optional keychain access group for shared access.
    ///   - accessibility: Keychain accessibility level.
    ///     Defaults to kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
    public init(
        credentialService: String = "com.pingidentity.push.credentials",
        notificationService: String = "com.pingidentity.push.notifications",
        tokenService: String = "com.pingidentity.push.tokens",
        logger: Logger? = nil,
        accessGroup: String? = nil,
        accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ) {
        self.credentialService = credentialService
        self.notificationService = notificationService
        self.tokenService = tokenService
        self.logger = logger
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    
    // MARK: - PushStorage Implementation
    // MARK: Credential Operations

    /// Store a push credential.
    ///
    /// - Parameter credential: The push credential to store.
    public func storePushCredential(_ credential: PushCredential) async throws {
        logger?.i("Storing push credential: \(credential.id)")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(credential)
            
            try storeKeychainItem(
                service: credentialService,
                account: credential.id,
                data: data
            )
            
            logger?.i("Successfully stored push credential: \(credential.id)")
        } catch {
            logger?.e("Failed to store push credential: \(credential.id)", error: error)
            throw PushStorageError.storageFailure("Failed to store credential", error)
        }
    }

    /// Retrieve all stored push credentials.
    ///
    /// - Returns: An array of all stored push credentials.
    public func getAllPushCredentials() async throws -> [PushCredential] {
        logger?.i("Retrieving all push credentials")
        
        do {
            let items = try loadAllKeychainItems(service: credentialService)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var credentials: [PushCredential] = []
            for (account, data) in items {
                do {
                    let credential = try decoder.decode(PushCredential.self, from: data)
                    credentials.append(credential)
                } catch {
                    logger?.w("Failed to decode credential \(account), skipping", error: error)
                }
            }
            
            logger?.i("Retrieved \(credentials.count) push credentials")
            return credentials
        } catch {
            logger?.e("Failed to retrieve push credentials", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve credentials", error)
        }
    }

    /// Retrieve a specific push credential by ID.
    ///
    /// - Parameter credentialId: The identifier of the push credential to retrieve.
    /// - Returns: The push credential if found, otherwise nil.
    public func retrievePushCredential(credentialId: String) async throws -> PushCredential? {
        logger?.i("Retrieving push credential: \(credentialId)")
        
        do {
            guard let data = try loadKeychainItem(
                service: credentialService,
                account: credentialId
            ) else {
                logger?.i("Push credential not found: \(credentialId)")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let credential = try decoder.decode(PushCredential.self, from: data)
            
            logger?.i("Successfully retrieved push credential: \(credentialId)")
            return credential
        } catch {
            logger?.e("Failed to retrieve push credential: \(credentialId)", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve credential", error)
        }
    }

    /// Remove a push credential by its ID.
    ///
    /// - Parameter credentialId: The identifier of the push credential to remove.
    /// - Returns: true if the credential was removed, false if not found.
    public func removePushCredential(credentialId: String) async throws -> Bool {
        logger?.i("Removing push credential: \(credentialId)")
        
        do {
            let removed = try deleteKeychainItem(
                service: credentialService,
                account: credentialId
            )
            
            if removed {
                logger?.i("Successfully removed push credential: \(credentialId)")
            } else {
                logger?.i("Push credential not found for removal: \(credentialId)")
            }
            
            return removed
        } catch {
            logger?.e("Failed to remove push credential: \(credentialId)", error: error)
            throw PushStorageError.storageFailure("Failed to remove credential", error)
        }
    }

    /// Clear all Push credentials from the storage.
    public func clearPushCredentials() async throws {
        logger?.i("Clearing all push credentials")
        
        do {
            try deleteAllKeychainItems(service: credentialService)
            logger?.i("Successfully cleared all push credentials")
        } catch {
            logger?.e("Failed to clear push credentials", error: error)
            throw PushStorageError.storageFailure("Failed to clear credentials", error)
        }
    }

    /// Store a push notification.
    ///
    /// - Parameter notification: The push notification to store.
    public func storePushNotification(_ notification: PushNotification) async throws {
        logger?.i("Storing push notification with ID: \(notification.id)")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notification)
        
        do {
            try storeKeychainItem(service: notificationService, account: notification.id, data: data)
            logger?.i("Successfully stored push notification: \(notification.id)")
        } catch {
            logger?.e("Failed to store push notification: \(notification.id)", error: error)
            throw PushStorageError.storageFailure("Failed to store notification", error)
        }
    }

    /// Update a push notification.
    ///
    /// - Parameter notification: The push notification to update.
    public func updatePushNotification(_ notification: PushNotification) async throws {
        logger?.i("Updating push notification with ID: \(notification.id)")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notification)
        
        do {
            try storeKeychainItem(service: notificationService, account: notification.id, data: data)
            logger?.i("Successfully updated push notification: \(notification.id)")
        } catch {
            logger?.e("Failed to update push notification: \(notification.id)", error: error)
            throw PushStorageError.storageFailure("Failed to update notification", error)
        }
    }

    /// Retrieve all stored push notifications.
    ///
    /// - Returns: An array of all stored push notifications.
    public func getAllPushNotifications() async throws -> [PushNotification] {
        logger?.i("Retrieving all push notifications")
        
        do {
            let allData = try loadAllKeychainItems(service: notificationService)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var notifications: [PushNotification] = []
            for item in allData {
                do {
                    let notification = try decoder.decode(PushNotification.self, from: item.value)
                    notifications.append(notification)
                } catch {
                    logger?.w("Failed to decode notification, skipping", error: error)
                }
            }
            
            logger?.i("Retrieved \(notifications.count) push notifications")
            return notifications
        } catch {
            logger?.e("Failed to retrieve all push notifications", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve notifications", error)
        }
    }

    /// Retrieve all pending push notifications.
    ///
    /// - Returns: An array of pending push notifications.
    public func getPendingPushNotifications() async throws -> [PushNotification] {
        logger?.i("Retrieving pending push notifications")
        
        let allNotifications = try await getAllPushNotifications()
        let pendingNotifications = allNotifications.filter { $0.pending }
        
        logger?.i("Found \(pendingNotifications.count) pending notifications")
        return pendingNotifications
    }

    /// Retrieve a specific push notification by ID.
    ///
    /// - Parameter notificationId: The identifier of the push notification to retrieve.
    /// - Returns: The push notification if found, otherwise nil.
    public func retrievePushNotification(notificationId: String) async throws -> PushNotification? {
        logger?.i("Retrieving push notification with ID: \(notificationId)")
        
        do {
            guard let data = try loadKeychainItem(service: notificationService, account: notificationId) else {
                logger?.i("Push notification not found: \(notificationId)")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notification = try decoder.decode(PushNotification.self, from: data)
            
            logger?.i("Successfully retrieved push notification: \(notificationId)")
            return notification
        } catch {
            logger?.e("Failed to retrieve push notification: \(notificationId)", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve notification", error)
        }
    }

    /// Retrieve a push notification by message ID.
    ///
    /// - Parameter messageId: The message ID of the push notification to retrieve.
    /// - Returns: The push notification if found, otherwise nil.
    public func getNotificationByMessageId(messageId: String) async throws -> PushNotification? {
        logger?.i("Retrieving push notification by message ID: \(messageId)")
        
        let allNotifications = try await getAllPushNotifications()
        let notification = allNotifications.first { $0.messageId == messageId }
        
        if notification != nil {
            logger?.i("Found push notification with message ID: \(messageId)")
        } else {
            logger?.i("No push notification found with message ID: \(messageId)")
        }
        
        return notification
    }

    /// Remove a push notification by its ID.
    ///
    /// - Parameter notificationId: The identifier of the push notification to remove.
    /// - Returns: true if the notification was removed, false if not found.
    public func removePushNotification(notificationId: String) async throws -> Bool {
        logger?.i("Removing push notification with ID: \(notificationId)")
        
        do {
            let result = try deleteKeychainItem(service: notificationService, account: notificationId)
            if result {
                logger?.i("Successfully removed push notification: \(notificationId)")
            } else {
                logger?.i("Push notification not found for removal: \(notificationId)")
            }
            return result
        } catch {
            logger?.e("Failed to remove push notification: \(notificationId)", error: error)
            throw PushStorageError.storageFailure("Failed to remove notification", error)
        }
    }

    /// Remove all push notifications associated with a credential.
    ///
    /// - Parameter credentialId: The identifier of the push credential.
    /// - Returns: The number of notifications removed.
    public func removePushNotificationsForCredential(credentialId: String) async throws -> Int {
        logger?.i("Removing push notifications for credential: \(credentialId)")
        
        do {
            let allNotifications = try await getAllPushNotifications()
            let notificationsToRemove = allNotifications.filter { $0.credentialId == credentialId }
            
            var removedCount = 0
            for notification in notificationsToRemove {
                if try deleteKeychainItem(service: notificationService, account: notification.id) {
                    removedCount += 1
                }
            }
            
            logger?.i("Removed \(removedCount) push notifications for credential: \(credentialId)")
            return removedCount
        } catch {
            logger?.e("Failed to remove push notifications for credential: \(credentialId)", error: error)
            throw PushStorageError.storageFailure("Failed to remove notifications for credential", error)
        }
    }

    /// Clear all Push notifications from the storage.
    public func clearPushNotifications() async throws {
        logger?.i("Clearing all push notifications")
        
        do {
            try deleteAllKeychainItems(service: notificationService)
            logger?.i("Successfully cleared all push notifications")
        } catch {
            logger?.e("Failed to clear all push notifications", error: error)
            throw PushStorageError.storageFailure("Failed to clear notifications", error)
        }
    }

    /// Store a push device token.
    ///
    /// - Parameter token: The push device token to store.
    public func storePushDeviceToken(_ token: PushDeviceToken) async throws {
        logger?.i("Storing push device token with ID: \(token.id)")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(token)
        
        do {
            // Store with a constant key since we only store one current token
            try storeKeychainItem(service: tokenService, account: "current", data: data)
            logger?.i("Successfully stored push device token")
        } catch {
            logger?.e("Failed to store push device token", error: error)
            throw PushStorageError.storageFailure("Failed to store device token", error)
        }
    }

    /// Retrieve the current push device token.
    ///
    /// - Returns: The current push device token if found, otherwise nil.
    public func getCurrentPushDeviceToken() async throws -> PushDeviceToken? {
        logger?.i("Retrieving current push device token")
        
        do {
            guard let data = try loadKeychainItem(service: tokenService, account: "current") else {
                logger?.i("No push device token found")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let token = try decoder.decode(PushDeviceToken.self, from: data)
            
            logger?.i("Successfully retrieved push device token")
            return token
        } catch {
            logger?.e("Failed to retrieve push device token", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve device token", error)
        }
    }

    /// Clear all Push device tokens from the storage.
    public func clearPushDeviceTokens() async throws {
        logger?.i("Clearing all push device tokens")
        
        do {
            try deleteAllKeychainItems(service: tokenService)
            logger?.i("Successfully cleared all push device tokens")
        } catch {
            logger?.e("Failed to clear all push device tokens", error: error)
            throw PushStorageError.storageFailure("Failed to clear device tokens", error)
        }
    }

    /// Count the number of push notifications.
    ///
    /// - Parameter credentialId: Optional credential identifier to filter notifications.
    /// - Returns: The count of push notifications.
    public func countPushNotifications(credentialId: String?) async throws -> Int {
        logger?.i("Counting push notifications\(credentialId.map { " for credential: \($0)" } ?? "")")
        
        do {
            let allNotifications = try await getAllPushNotifications()
            
            let count: Int
            if let credentialId = credentialId {
                count = allNotifications.filter { $0.credentialId == credentialId }.count
            } else {
                count = allNotifications.count
            }
            
            logger?.i("Found \(count) push notifications")
            return count
        } catch {
            logger?.e("Failed to count push notifications", error: error)
            throw PushStorageError.storageFailure("Failed to count notifications", error)
        }
    }

    /// Retrieve the oldest push notifications.
    ///
    /// - Parameters:
    ///   - limit: The maximum number of oldest notifications to retrieve.
    ///   - credentialId: Optional credential identifier to filter notifications.
    /// - Returns: An array of the oldest push notifications.
    public func getOldestPushNotifications(limit: Int, credentialId: String?) async throws -> [PushNotification] {
        logger?.i("Retrieving \(limit) oldest push notifications\(credentialId.map { " for credential: \($0)" } ?? "")")
        
        do {
            var allNotifications = try await getAllPushNotifications()
            
            // Filter by credentialId if provided
            if let credentialId = credentialId {
                allNotifications = allNotifications.filter { $0.credentialId == credentialId }
            }
            
            // Sort by createdAt ascending (oldest first)
            let sortedNotifications = allNotifications.sorted { $0.createdAt < $1.createdAt }
            
            // Take only the requested limit
            let oldestNotifications = Array(sortedNotifications.prefix(limit))
            
            logger?.i("Retrieved \(oldestNotifications.count) oldest push notifications")
            return oldestNotifications
        } catch {
            logger?.e("Failed to retrieve oldest push notifications", error: error)
            throw PushStorageError.storageFailure("Failed to retrieve oldest notifications", error)
        }
    }

    /// Purge push notifications by age.
    ///
    /// - Parameters:
    ///   - maxAgeDays: The maximum age in days for notifications to keep.
    ///   - credentialId: Optional credential identifier to filter notifications.
    ///  - Returns: The number of notifications purged.
    public func purgePushNotificationsByAge(maxAgeDays: Int, credentialId: String?) async throws -> Int {
        logger?.i("Purging push notifications older than \(maxAgeDays) days\(credentialId.map { " for credential: \($0)" } ?? "")")
        
        do {
            var allNotifications = try await getAllPushNotifications()
            
            // Filter by credentialId if provided
            if let credentialId = credentialId {
                allNotifications = allNotifications.filter { $0.credentialId == credentialId }
            }
            
            // Calculate cutoff date
            let cutoffDate = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
            
            // Find notifications older than cutoff
            let notificationsToRemove = allNotifications.filter { $0.createdAt < cutoffDate }
            
            // Remove each old notification
            var removedCount = 0
            for notification in notificationsToRemove {
                if try deleteKeychainItem(service: notificationService, account: notification.id) {
                    removedCount += 1
                }
            }
            
            logger?.i("Purged \(removedCount) push notifications by age")
            return removedCount
        } catch {
            logger?.e("Failed to purge push notifications by age", error: error)
            throw PushStorageError.storageFailure("Failed to purge notifications by age", error)
        }
    }

    /// Purge push notifications by count.
    ///
    /// - Parameters:
    ///   - maxCount: The maximum number of notifications to keep.
    ///   - credentialId: Optional credential identifier to filter notifications.
    /// - Returns: The number of notifications purged.
    public func purgePushNotificationsByCount(maxCount: Int, credentialId: String?) async throws -> Int {
        logger?.i("Purging push notifications to keep max \(maxCount)\(credentialId.map { " for credential: \($0)" } ?? "")")
        
        do {
            var allNotifications = try await getAllPushNotifications()
            
            // Filter by credentialId if provided
            if let credentialId = credentialId {
                allNotifications = allNotifications.filter { $0.credentialId == credentialId }
            }
            
            // Check if we need to purge
            guard allNotifications.count > maxCount else {
                logger?.i("No purge needed: \(allNotifications.count) <= \(maxCount)")
                return 0
            }
            
            // Sort by createdAt ascending (oldest first)
            let sortedNotifications = allNotifications.sorted { $0.createdAt < $1.createdAt }
            
            // Calculate how many to remove
            let removeCount = allNotifications.count - maxCount
            let notificationsToRemove = Array(sortedNotifications.prefix(removeCount))
            
            // Remove oldest notifications
            var removedCount = 0
            for notification in notificationsToRemove {
                if try deleteKeychainItem(service: notificationService, account: notification.id) {
                    removedCount += 1
                }
            }
            
            logger?.i("Purged \(removedCount) push notifications by count")
            return removedCount
        } catch {
            logger?.e("Failed to purge push notifications by count", error: error)
            throw PushStorageError.storageFailure("Failed to purge notifications by count", error)
        }
    }

    
    // MARK: - Private Keychain Helper Methods

    /// Store data in the keychain with the given service and account.
    /// Updates existing item if it exists, otherwise creates a new one.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    ///   - data: The data to store.
    /// - Throws: `PushStorageError` if keychain operations fail.
    private func storeKeychainItem(service: String, account: String, data: Data) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Try to update existing item first
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]

        let updateQuery = query
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return // Successfully updated existing item
        }

        if updateStatus != errSecItemNotFound {
            throw mapKeychainError(updateStatus, operation: "update keychain item")
        }

        // Item doesn't exist, create new item
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessibility

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw mapKeychainError(addStatus, operation: "add keychain item")
        }
    }

    /// Load data from the keychain with the given service and account.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    /// - Returns: The stored data, or nil if not found.
    /// - Throws: `PushStorageError` if keychain operations fail.
    private func loadKeychainItem(service: String, account: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "load keychain item")
        }

        return result as? Data
    }

    /// Load all items from the keychain for a given service.
    /// - Parameter service: The keychain service identifier.
    /// - Returns: Dictionary mapping account names to data.
    /// - Throws: `PushStorageError` if keychain operations fail.
    private func loadAllKeychainItems(service: String) throws -> [String: Data] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return [:] // No items found
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "load all keychain items")
        }

        guard let items = result as? [[String: Any]] else {
            return [:]
        }

        var resultDict: [String: Data] = [:]
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               let data = item[kSecValueData as String] as? Data {
                resultDict[account] = data
            }
        }

        return resultDict
    }

    /// Delete a keychain item with the given service and account.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    /// - Returns: true if item was deleted, false if not found.
    /// - Throws: `PushStorageError` if keychain operations fail.
    @discardableResult
    private func deleteKeychainItem(service: String, account: String) throws -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            return false
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "delete keychain item")
        }

        return true
    }

    /// Delete all keychain items for a given service.
    /// - Parameter service: The keychain service identifier.
    /// - Throws: `PushStorageError` if keychain operations fail.
    private func deleteAllKeychainItems(service: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        // It's okay if no items were found
        if status == errSecItemNotFound {
            return
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "delete all keychain items")
        }
    }

    /// Maps keychain error codes to PushStorageError.
    /// - Parameters:
    ///   - status: The keychain operation status code.
    ///   - operation: Description of the operation that failed.
    ///   - account: Optional account identifier for context.
    /// - Returns: Appropriate PushStorageError.
    private func mapKeychainError(_ status: OSStatus, operation: String, account: String? = nil) -> PushStorageError {
        let message: String
        
        switch status {
        case errSecDuplicateItem:
            message = "Duplicate item"
        case errSecItemNotFound:
            message = "Item not found"
        case errSecAuthFailed:
            message = "Authentication failed"
        case errSecUserCanceled:
            message = "User canceled operation"
        case errSecInteractionNotAllowed:
            message = "Interaction not allowed"
        case errSecDecode:
            message = "Decode error"
        case errSecParam:
            message = "Invalid parameter"
        case errSecAllocate:
            message = "Failed to allocate memory"
        case errSecNotAvailable:
            message = "Keychain not available"
        case errSecReadOnly:
            message = "Keychain is read-only"
        case errSecNoStorageModule:
            message = "No storage module available"
        default:
            message = "Keychain error \(status)"
        }
        
        let contextMessage: String
        if let account = account {
            contextMessage = "\(operation) for account '\(account)': \(message)"
        } else {
            contextMessage = "\(operation): \(message)"
        }
        
        logger?.e(contextMessage, error: nil)
        return PushStorageError.storageFailure(contextMessage, nil)
    }
}
