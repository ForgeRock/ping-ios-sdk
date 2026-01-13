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
    /// Legacy keychain key for the identifier
    private static let legacyIdentifierKey = "com.forgerock.ios.device-identifier.hash-base64-string-identifier"
    /// Legacy keychain key for public key data
    private static let legacyPublicKeyDataKey = "com.forgerock.ios.device-identifier.pubic-key.data"
    
    private let keychainService: any Storage<String>
    private let logger: Logger?
    
    /// Initializes the legacy device identifier retriever
    /// - Parameters:
    ///   - keychainService: Storage service to access legacy keychain items
    ///   - logger: Optional logger for diagnostic messages
    init(keychainService: any Storage<String>, logger: Logger? = nil) {
        self.keychainService = keychainService
        self.logger = logger
    }
    
    /// Attempts to retrieve the legacy device identifier
    /// - Returns: The legacy identifier if it exists, otherwise nil
    func getLegacyIdentifier() async throws -> String? {
        logger?.i("Checking for legacy device identifier")
        
        // First try to get the stored identifier directly
        if let identifier = try await keychainService.get() {
            logger?.i("Found legacy device identifier in keychain")
            return identifier
        }
        
        logger?.d("No legacy device identifier found")
        return nil
    }
    
    /// Creates a legacy keychain storage instance
    /// - Parameter account: Keychain account (typically the legacy identifier key)
    /// - Returns: Storage instance configured for legacy keychain access
    static func createLegacyStorage(account: String = legacyIdentifierKey, logger: Logger? = nil) -> any Storage<String> {
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
        
        // Create storage for public key data
        let publicKeyStorage = KeychainStorage<Data>(
            account: Self.legacyPublicKeyDataKey,
            encryptor: NoEncryptor()
        )
        
        guard let keyData = try await publicKeyStorage.get() else {
            logger?.d("No legacy public key data found")
            return nil
        }
        
        logger?.i("Found legacy public key data, regenerating identifier")
        let identifier = hashAndBase64Data(keyData)
        
        // Store the regenerated identifier for future retrievals
        try await keychainService.save(item: identifier)
        
        return identifier
    }
    
    /// Hashes given Data using SHA1 and returns hex string
    /// This matches the legacy FRDeviceIdentifier hashing behavior
    /// - Parameter data: Data to be hashed
    /// - Returns: Hashed hex string of given Data
    private func hashAndBase64Data(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        // Inline hex conversion to avoid extension conflicts
        let hashData = Data(bytes: digest, count: digest.count)
        return hashData.toHexString()
    }
}
