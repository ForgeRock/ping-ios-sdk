//
//  LegacyUserKeysStorage.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Legacy keychain service identifier used in the old SDK version
private let legacyKeychainServiceIdentifier = "com.forgerock.ios.devicebinding.keychainservice"

/// Storage for accessing device binding data from the legacy SDK version.
///
/// This class provides read-only access to user key metadata that was stored by the legacy SDK
/// in the keychain under the service identifier `com.forgerock.ios.devicebinding.keychainservice`.
/// It's used during the migration process to retrieve all user keys and migrate them to the new storage format.
///
/// The legacy SDK stored an array of `UserKey` objects (or similar structure) as JSON data in the keychain.
///
/// ## Usage in Migration
///
/// This class is used in the device binding migration to:
/// 1. Check if legacy user key data exists
/// 2. Retrieve all user keys from the legacy keychain location
/// 3. Migrate the keys to the new storage format
/// 4. Clean up the legacy data after successful migration
///
/// ## Keychain Query Parameters
///
/// The legacy data is queried using:
/// - Service: `com.forgerock.ios.devicebinding.keychainservice`
/// - Account: `devicebinding.userkeys` (assumed based on Android pattern)
/// - Access Group: Optional, if the app was configured with keychain access group
///
class LegacyUserKeysStorage {
    
    private let logger: Logger?
    private let accessGroup: String?
    
    /// The account name used for the legacy user keys in keychain
    private let legacyAccount = "devicebinding.userkeys"
    
    /// Initializes a new `LegacyUserKeysStorage`.
    /// - Parameters:
    ///   - accessGroup: The keychain access group, if any was configured in the legacy app
    ///   - logger: Optional logger for debugging
    init(accessGroup: String? = nil, logger: Logger? = nil) {
        self.accessGroup = accessGroup
        self.logger = logger
    }
    
    /// Checks if legacy keychain data exists.
    ///
    /// This method queries the keychain to determine whether legacy device binding data
    /// is present. It's used to decide if migration is necessary before attempting to read data.
    ///
    /// - Returns: `true` if legacy data exists in the keychain, `false` otherwise.
    func exists() async -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainServiceIdentifier,
            kSecAttrAccount as String: legacyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: false
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        let exists = status == errSecSuccess
        
        logger?.i("Legacy keychain data exists: \(exists)")
        return exists
    }
    
    /// Retrieves all user keys stored in the legacy keychain location.
    ///
    /// This method reads the legacy keychain entry, decodes the JSON data into an array
    /// of `UserKey` objects, and returns them for migration to the new storage format.
    ///
    /// The method performs the following steps:
    /// 1. Queries the keychain for the legacy data
    /// 2. Decodes the JSON data into `[UserKey]`
    /// 3. Returns the array of user keys
    ///
    /// - Returns: An array of `UserKey` objects from the legacy storage.
    /// - Throws: `MigrationError.noLegacyDataFound` if no data exists,
    ///           `MigrationError.invalidLegacyData` if the data cannot be decoded.
    func getAllKeys() async throws -> [UserKey] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainServiceIdentifier,
            kSecAttrAccount as String: legacyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            logger?.i("No legacy data found in keychain (status: \(status))")
            throw MigrationError.noLegacyDataFound
        }
        
        logger?.i("Found legacy keychain data (\(data.count) bytes)")
        
        do {
            let userKeys = try JSONDecoder().decode([UserKey].self, from: data)
            logger?.i("Successfully decoded \(userKeys.count) user keys from legacy storage")
            return userKeys
        } catch {
            logger?.e("Failed to decode legacy user keys", error: error)
            throw MigrationError.invalidLegacyData("Failed to decode JSON: \(error.localizedDescription)")
        }
    }
    
    /// Deletes the legacy keychain data.
    ///
    /// This method should be called after successfully migrating all user keys to the new storage format.
    /// It removes the legacy keychain entry to ensure clean migration and prevent data duplication.
    ///
    /// - Throws: `MigrationError.failedToDeleteLegacyData` if the deletion fails.
    func deleteLegacyData() async throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainServiceIdentifier,
            kSecAttrAccount as String: legacyAccount
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Consider success if item was deleted or didn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger?.e("Failed to delete legacy keychain data (status: \(status))", error: nil)
            throw MigrationError.failedToDeleteLegacyData(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                    NSLocalizedDescriptionKey: "SecItemDelete failed with status: \(status)"
                ])
            )
        }
        
        logger?.i("Successfully deleted legacy keychain data")
    }
}
