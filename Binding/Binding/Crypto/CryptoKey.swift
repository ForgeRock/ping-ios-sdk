
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import Security

/// A class for managing cryptographic keys in the Keychain.
class CryptoKey {
    
    private let keyTag: String
    
    init(keyTag: String) {
        self.keyTag = keyTag
    }
    
    /// Generates a new key pair.
    ///
    /// - Parameter attestation: The attestation type.
    /// - Returns: The generated key pair.
    func generateKeyPair(attestation: Attestation) throws -> KeyPair {
        let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                     .privateKeyUsage,
                                                     nil)
        
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
                kSecAttrAccessControl as String: access as Any
            ]
        ]
        
        if case .challenge(let challenge) = attestation {
            attributes[kSecAttrApplicationParameters as String] = challenge.data(using: .utf8)
        }
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as? Error ?? DeviceBindingError.unknown
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw DeviceBindingError.unknown
        }
        
        return KeyPair(publicKey: publicKey, privateKey: privateKey, keyTag: keyTag)
    }
    
    /// Gets the public key.
    ///
    /// - Returns: The public key.
    func getPublicKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item as? SecKey else {
            throw DeviceBindingError.deviceNotRegistered
        }
        return key
    }
    
    /// Deletes the key pair.
    func deleteKeyPair() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data()
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeviceBindingError.unknown
        }
    }
}
