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
        /// Legacy keychain tag for public key in system keychain
        static let publicKeyTag = "com.forgerock.ios.device-identifier.public-key"
        /// Legacy keychain tag for private key in system keychain
        static let privateKeyTag = "com.forgerock.ios.device-identifier.private-key"
    }
    
    private let logger: Logger?
    private let accessGroup: String?
    
    /// Initializes the legacy device identifier retriever
    /// - Parameters:
    ///   - accessGroup: Optional keychain access group used by the legacy SDK
    ///   - logger: Optional logger for diagnostic messages
    init(accessGroup: String? = nil, logger: Logger? = nil) {
        self.accessGroup = accessGroup
        self.logger = logger
    }
    
    /// Attempts to retrieve the legacy device identifier directly from keychain
    /// Uses raw Security framework queries to match FRAuth SDK's KeychainService behavior
    /// - Returns: The legacy identifier if it exists, otherwise nil
    func getLegacyIdentifier() async throws -> String? {
        logger?.i("Checking for legacy device identifier using direct keychain query")
        
        return await Task.detached { [accessGroup, logger] () -> String? in
            // Build query matching FRAuth SDK's KeychainService
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyKeychainKeys.identifier,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            // Add access group if specified
            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
                logger?.i("Using legacy keychain access group: \(accessGroup)")
            }
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data, let identifier = String(data: data, encoding: .utf8) {
                logger?.i("Found legacy device identifier in keychain")
                return identifier
            } else if status == errSecItemNotFound {
                logger?.d("No legacy device identifier found (errSecItemNotFound)")
                return nil
            } else {
                logger?.w("Failed to retrieve legacy identifier. Status: \(status)", error: nil)
                return nil
            }
        }.value
    }
    
    /// Attempts to migrate legacy RSA key pair from system keychain
    /// - Returns: A tuple containing the legacy identifier and key pair data if found, otherwise nil
    func migrateLegacyKeyPair() async throws -> (identifier: String, keyPair: DeviceIdentifierKeyPair)? {
        logger?.i("Attempting to migrate legacy RSA key pair from system keychain")
        
        let publicKeyTag = LegacyKeychainKeys.publicKeyTag.data(using: .utf8)!
        let privateKeyTag = LegacyKeychainKeys.privateKeyTag.data(using: .utf8)!
        
        // Query for public key
        let publicKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: publicKeyTag,
            kSecReturnRef as String: true
        ]
        
        var publicKeyResult: AnyObject?
        let publicKeyStatus = SecItemCopyMatching(publicKeyQuery as CFDictionary, &publicKeyResult)
        
        guard publicKeyStatus == errSecSuccess, let publicSecKey = publicKeyResult as! SecKey? else {
            if publicKeyStatus == errSecItemNotFound {
                logger?.d("No legacy public key found in system keychain")
            } else {
                logger?.w("Failed to query for legacy public key. Status: \(publicKeyStatus)", error: nil)
            }
            return nil
        }
        
        logger?.i("Found legacy RSA public key in system keychain")
        
        // Export public key
        var publicError: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicSecKey, &publicError) as Data? else {
            logger?.e("Could not export legacy public key", error: publicError?.takeRetainedValue())
            return nil
        }
        
        logger?.i("Exported legacy public key: \(publicKeyData.count) bytes")
        
        // Query for private key
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: privateKeyTag,
            kSecReturnRef as String: true
        ]
        
        var privateKeyResult: AnyObject?
        let privateKeyStatus = SecItemCopyMatching(privateKeyQuery as CFDictionary, &privateKeyResult)
        
        var privateKeyData: Data?
        if privateKeyStatus == errSecSuccess, let privateSecKey = privateKeyResult as! SecKey? {
            logger?.i("Found legacy RSA private key in system keychain")
            
            var privateError: Unmanaged<CFError>?
            if let exportedPrivateKey = SecKeyCopyExternalRepresentation(privateSecKey, &privateError) as Data? {
                privateKeyData = exportedPrivateKey
                logger?.i("Exported legacy private key: \(exportedPrivateKey.count) bytes")
            } else {
                logger?.w("Could not export legacy private key, continuing with public key only", error: privateError?.takeRetainedValue())
            }
        } else {
            logger?.d("No legacy private key found in system keychain (Status: \(privateKeyStatus))")
        }
        
        // Generate identifier from public key (matching FRAuth SDK)
        let identifier = hashAndBase64Data(publicKeyData)
        logger?.i("Generated identifier from legacy key: \(identifier)")
        
        // Create key pair (private key may be nil/empty)
        let keyPair = DeviceIdentifierKeyPair(
            privateKey: privateKeyData,
            publicKey: publicKeyData
        )
        
        return (identifier: identifier, keyPair: keyPair)
    }
    
    /// Attempts to regenerate legacy identifier from public key (for backward compatibility)
    /// - Returns: The legacy identifier if public key is found, otherwise nil
    func migrateLegacyIdentifierFromPublicKey() async throws -> String? {
        // Try to migrate the full key pair first
        if let migration = try await migrateLegacyKeyPair() {
            return migration.identifier
        }
        return nil
    }
    
    /// Hashes given Data using SHA1 and returns hex string
    /// This matches the legacy FRDeviceIdentifier hashing behavior
    /// - Parameter data: Data to be hashed
    /// - Returns: Hex-encoded string of the SHA1 hash (40 characters)
    private func hashAndBase64Data(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hashData = Data(bytes: digest, count: digest.count)
        return hashData.toHexString()
    }
}
