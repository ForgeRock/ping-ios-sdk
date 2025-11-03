
//
//  CryptoKey.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import LocalAuthentication

/// A class for managing cryptographic keys in the Keychain.
/// This class provides methods for generating, retrieving, and deleting key pairs.
public class CryptoKey {
    
    /// The tag that uniquely identifies the key in the Keychain.
    public let keyTag: String
    
    /// Initializes a new `CryptoKey` with the given key tag.
    /// - Parameter keyTag: The key tag to use.
    public init(keyTag: String) {
        self.keyTag = keyTag
    }
    
    /// Generates a new elliptic curve key pair and stores it in the Secure Enclave.
    ///
    /// - Parameter attestation: The attestation type. Currently, this parameter is not used.
    /// - Parameter accessControl: The access control flags for the key. If nil, a default will be used.
    /// - Parameter keySizeInBits: The key size in bits (256 for P-256, 521 for P-521). Defaults to 256.
    /// - Returns: The generated `KeyPair`.
    /// - Throws: A `DeviceBindingError` if the key generation fails.
    public func generateKeyPair(attestation: Attestation, accessControl: SecAccessControl? = nil, keySizeInBits: Int = 256, pin: String? = nil) throws -> KeyPair {
        let access = accessControl ?? SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                      .privateKeyUsage,
                                                                      nil)!
        
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: keySizeInBits,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
                kSecAttrAccessControl as String: access
            ]
        ]
        
        
        if let pinData = pin?.data(using: .utf8) {
#if !targetEnvironment(simulator)
            let context = LAContext()
            let credentialIsSet = context.setCredential(pinData, type: .applicationPassword)
            guard credentialIsSet == true else { throw NSError() }
            attributes[String(kSecUseAuthenticationContext)] = context
#endif
        }
        
        /*if case .challenge(let challenge) = attestation {
         attributes[kSecAttrApplicationParameters as String] = challenge.data(using: .utf8)
         }*/
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as? Error ?? DeviceBindingError.unknown
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw DeviceBindingError.unknown
        }
        
        return KeyPair(publicKey: publicKey, privateKey: privateKey, keyTag: keyTag)
    }
    
    /// Gets the public key from the Keychain.
    ///
    /// - Returns: The public key as a `SecKey`.
    /// - Throws: A `DeviceBindingError.deviceNotRegistered` if the key is not found.
    public func getPublicKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item = item else {
            throw DeviceBindingError.deviceNotRegistered
        }
        return (item as! SecKey)
    }
    
    /// Deletes the key pair from the Keychain.
    /// - Throws: A `DeviceBindingError.unknown` if the deletion fails for any reason other than the item not being found.
    public func deleteKeyPair() throws {
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

