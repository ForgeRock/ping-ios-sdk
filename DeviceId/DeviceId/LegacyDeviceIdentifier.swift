//
//  LegacyDeviceIdentifier.swift
//  DeviceId
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CommonCrypto
import PingLogger
import PingStorage

/// Legacy device identifier retrieval from FRAuth SDK format.
/// This class handles migration from the old FRDeviceIdentifier format to the new DeviceId module format.
internal actor LegacyDeviceIdentifier {
    
    // MARK: - Legacy Keychain Constants
    
    /// Legacy keychain keys from FRAuth SDK
    enum LegacyKeychainKeys {
        /// Legacy keychain key for the identifier
        static let identifier = "com.forgerock.ios.device-identifier.hash-base64-string-identifier"
        /// Legacy keychain key for public key data
        static let publicKeyData = "com.forgerock.ios.device-identifier.pubic-key.data"
        /// Legacy keychain key for private key data
        static let privateKeyData = "com.forgerock.ios.device-identifier.private-key.data"
    }
    
    private let logger: Logger?
    
    /// Initializes the legacy device identifier retriever
    /// - Parameters:
    ///   - logger: Optional logger for diagnostic messages
    init(logger: Logger? = nil) {
        self.logger = logger
    }
    
    /// Attempts to retrieve the legacy device identifier directly from keychain
    /// Uses raw Security framework queries to match FRAuth SDK's KeychainService behavior
    /// - Returns: The legacy identifier if it exists, otherwise nil
    func getLegacyIdentifier() async throws -> String? {
        logger?.i("Checking for legacy device identifier using direct keychain query")
        
        return await Task.detached { () -> String? in
            // Build query matching FRAuth SDK's KeychainService
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyKeychainKeys.identifier,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            // Add access group if available (same as FRAuth SDK would use)
            if let accessGroup = await self.getKeychainAccessGroup() {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data, let identifier = String(data: data, encoding: .utf8) {
                self.logger?.i("Found legacy device identifier in keychain")
                return identifier
            } else if status == errSecItemNotFound {
                self.logger?.d("No legacy device identifier found (errSecItemNotFound)")
                return nil
            } else {
                self.logger?.w("Failed to retrieve legacy identifier. Status: \(status)", error: nil)
                return nil
            }
        }.value
    }
    
    /// Creates a legacy keychain storage instance
    /// - Parameter account: Keychain account (typically the legacy identifier key)
    /// - Returns: Storage instance configured for legacy keychain access
    static func createLegacyStorage(account: String = LegacyKeychainKeys.identifier, logger: Logger? = nil) -> any Storage<String> {
        return KeychainStorage<String>(
            account: account,
            encryptor: NoEncryptor()
        )
    }
    
    /// Attempts to migrate legacy identifier by regenerating it from public key data if needed
    /// This handles the case where the identifier exists but may need regeneration
    /// - Returns: The migrated identifier if successful, otherwise nil
    func migrateLegacyIdentifierFromPublicKey() async throws -> String? {
        logger?.i("Attempting to regenerate legacy identifier from public key data")
        
        return await Task.detached { () -> String? in
            // Build query for legacy public key data
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyKeychainKeys.publicKeyData,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            // Add access group if available
            if let accessGroup = await self.getKeychainAccessGroup() {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            guard status == errSecSuccess, let keyData = result as? Data else {
                if status == errSecItemNotFound {
                    self.logger?.d("No legacy public key data found")
                } else {
                    self.logger?.w("Failed to retrieve legacy public key. Status: \(status)", error: nil)
                }
                return nil
            }
            
            self.logger?.i("Found legacy public key data, regenerating identifier")
            let identifier = await self.hashAndBase64Data(keyData)
            
            // Store the regenerated identifier using raw keychain for consistency
            await self.saveLegacyIdentifier(identifier)
            
            return identifier
        }.value
    }
    
    /// Saves the legacy identifier to keychain using direct Security framework calls
    /// - Parameter identifier: The identifier to save
    private func saveLegacyIdentifier(_ identifier: String) async {
        await Task.detached {
            guard let data = identifier.data(using: .utf8) else {
                self.logger?.e("Failed to encode identifier as UTF-8", error: nil)
                return
            }
            
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyKeychainKeys.identifier,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            if let accessGroup = await self.getKeychainAccessGroup() {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            
            // Try to add, if it exists, update it
            var status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecDuplicateItem {
                let updateQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: LegacyKeychainKeys.identifier
                ]
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: data
                ]
                status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            }
            
            if status != errSecSuccess {
                self.logger?.w("Failed to save regenerated legacy identifier. Status: \(status)", error: nil)
            } else {
                self.logger?.i("Successfully saved regenerated legacy identifier")
            }
        }.value
    }
    
    /// Gets the keychain access group if configured
    /// This should match the access group used by FRAuth SDK
    /// - Returns: Access group string if available
    private func getKeychainAccessGroup() -> String? {
        // Check if there's a configured access group in the app's entitlements
        // FRAuth SDK would use the first access group from keychain-access-groups
        // For now, return nil to search in the default group
        // This can be enhanced to read from configuration if needed
        return nil
    }
    
    /// Hashes given Data using SHA1 and returns base64-encoded string
    /// This matches the legacy FRDeviceIdentifier hashing behavior
    /// - Parameter data: Data to be hashed
    /// - Returns: Base64-encoded string of the SHA1 hash
    private func hashAndBase64Data(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hashData = Data(bytes: digest, count: digest.count)
        return hashData.base64EncodedString()
    }
}
