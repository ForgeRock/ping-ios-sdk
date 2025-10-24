/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// An authenticator that does not require any user interaction.
class NoneAuthenticator: DeviceAuthenticator {
    
    /// The type of authenticator.
    let type: DeviceBindingAuthenticationType = .none
    
    /// Registers a new key pair.
    /// - Parameter attestation: The attestation to use.
    /// - Returns: The new key pair.
    func register(attestation: Attestation) async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        return try cryptoKey.generateKeyPair(attestation: attestation)
    }
    
    /// Authenticates the user.
    /// - Returns: The private key.
    func authenticate() async throws -> SecKey {
        return try getPrivateKey()
    }
    
    /// Checks if the authenticator is supported.
    /// - Parameter attestation: The attestation to use.
    /// - Returns: `true` if the authenticator is supported, `false` otherwise.
    func isSupported(attestation: Attestation) -> Bool {
        return true
    }
    
    /// Deletes all keys associated with this authenticator.
    func deleteKeys() async throws {
        let userKeys = try UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .none {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    /// Gets the private key from the keychain.
    /// - Returns: The private key.
    private func getPrivateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "".data(using: .utf8) ?? Data(),
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
}
