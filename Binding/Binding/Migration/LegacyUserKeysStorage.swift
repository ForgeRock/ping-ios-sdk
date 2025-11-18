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
/// The legacy SDK stored each `UserKey` individually as a JSON string in the keychain,
/// using the service identifier and the user key's ID as the account name.
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
/// - Account: Each `UserKey.id` (multiple entries, one per key)
/// - Access Group: Optional, if the app was configured with keychain access group
///
class LegacyUserKeysStorage {
    
    private let logger: Logger?
    private let accessGroup: String?
    
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
    /// This method queries the keychain for all entries with the legacy service identifier,
    /// then decodes each individual JSON string into a `UserKey` object.
    ///
    /// The legacy SDK stored each key separately with:
    /// - Service: `com.forgerock.ios.devicebinding.keychainservice`
    /// - Account: The user key's ID
    /// - Data: JSON string of the UserKey
    ///
    /// The method performs the following steps:
    /// 1. Queries the keychain for all legacy entries
    /// 2. Iterates through each entry and decodes the JSON string
    /// 3. Returns the array of user keys
    ///
    /// - Returns: An array of `UserKey` objects from the legacy storage.
    /// - Throws: `MigrationError.noLegacyDataFound` if no data exists,
    ///           `MigrationError.invalidLegacyData` if the data cannot be decoded.
    func getAllKeys() async throws -> [UserKey] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainServiceIdentifier,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess else {
            logger?.i("No legacy data found in keychain (status: \(status))")
            throw MigrationError.noLegacyDataFound
        }
        
        guard let keychainItems = items as? [[String: Any]] else {
            logger?.i("No legacy keychain items found")
            throw MigrationError.noLegacyDataFound
        }
        
        logger?.i("Found \(keychainItems.count) legacy keychain entries")
        
        var userKeys: [UserKey] = []
        var failedCount = 0
        
        for item in keychainItems {
            guard let data = item[kSecValueData as String] as? Data else {
                failedCount += 1
                continue
            }
            
            do {
                // The legacy format stored data as a JSON string in the keychain
                // We need to convert Data -> String -> Data to properly decode
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    failedCount += 1
                    logger?.w("Failed to convert keychain data to string", error: nil)
                    continue
                }
                
                logger?.i("Decoding legacy key from JSON: \(jsonString.prefix(100))...")
                
                // Parse the legacy JSON to transform field names
                guard let jsonDict = try JSONSerialization.jsonObject(with: Data(jsonString.utf8)) as? [String: Any] else {
                    failedCount += 1
                    logger?.w("Failed to parse legacy JSON as dictionary", error: nil)
                    continue
                }
                
                // Transform the legacy format to match the new UserKey structure
                // Legacy: {id, userId, userName, kid, authType, createdAt}
                // New:    {keyTag, userId, username, kid, authType, createdAt}
                var transformedDict: [String: Any] = [:]
                
                // Map legacy field names to new field names
                if let id = jsonDict["id"] as? String {
                    transformedDict["keyTag"] = id
                }
                if let userId = jsonDict["userId"] as? String {
                    transformedDict["userId"] = userId
                }
                if let userName = jsonDict["userName"] as? String {
                    transformedDict["username"] = userName  // userName -> username
                }
                if let kid = jsonDict["kid"] as? String {
                    transformedDict["kid"] = kid
                }
                if let authType = jsonDict["authType"] as? String {
                    transformedDict["authType"] = authType
                }
                // Convert timestamp (Double) to ISO8601 string for Date decoding
                if let createdAtTimestamp = jsonDict["createdAt"] as? Double {
                    let date = Date(timeIntervalSince1970: createdAtTimestamp)
                    transformedDict["createdAt"] = date.timeIntervalSince1970
                }
                
                // Convert back to JSON data
                let transformedData = try JSONSerialization.data(withJSONObject: transformedDict)
                
                // Decode using a custom decoder that handles the timestamp
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                
                let userKey = try decoder.decode(UserKey.self, from: transformedData)
                userKeys.append(userKey)
                
                logger?.i("Successfully decoded legacy key for user: \(userKey.userId)")
            } catch {
                failedCount += 1
                logger?.w("Failed to decode legacy user key: \(error.localizedDescription)", error: error)
            }
        }
        
        if userKeys.isEmpty {
            logger?.e("No valid user keys found in legacy storage (failed: \(failedCount))", error: nil)
            throw MigrationError.invalidLegacyData("Failed to decode any user keys from \(keychainItems.count) entries")
        }
        
        logger?.i("Successfully decoded \(userKeys.count) user keys from legacy storage (failed: \(failedCount))")
        return userKeys
    }
    
    /// Deletes all legacy keychain entries.
    ///
    /// This method removes all legacy keychain entries with the legacy service identifier.
    /// Since the legacy SDK stored each key separately, this will delete all entries
    /// that match the service identifier (without specifying an account name).
    ///
    /// - Throws: `MigrationError.failedToDeleteLegacyData` if the deletion fails.
    func deleteLegacyData() async throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainServiceIdentifier
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Consider success if items were deleted or didn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger?.e("Failed to delete legacy keychain data (status: \(status))", error: nil)
            throw MigrationError.failedToDeleteLegacyData(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                    NSLocalizedDescriptionKey: "SecItemDelete failed with status: \(status)"
                ])
            )
        }
        
        if status == errSecSuccess {
            logger?.i("Successfully deleted all legacy keychain entries")
        } else {
            logger?.i("No legacy keychain entries to delete")
        }
    }
}
