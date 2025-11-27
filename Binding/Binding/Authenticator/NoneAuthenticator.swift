
//
//  NoneAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// An authenticator that does not require any user interaction.
/// This authenticator is used when the authentication type is `none`.
public class NoneAuthenticator: DefaultDeviceAuthenticator {
    
    /// The type of authenticator, which is `.none`.
    public override func type() -> DeviceBindingAuthenticationType {
        return .none
    }
    
    /// Generates a new key pair without any specific access control.
    /// - Returns: A new `KeyPair`.
    /// - Throws: A `CryptoKeyError` if key generation fails.
    public override func register() async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        return try cryptoKey.generateKeyPair(attestation: .none)
    }
    
    /// - Returns: A `Result` containing the `SecKey` on success, or an `Error` on failure.
    public override func authenticate(keyTag: String) async -> Result<SecKey, Error> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item = item else {
            return .failure(DeviceBindingError.deviceNotRegistered)
        }
        return .success(item as! SecKey)
    }
    
    /// Checks if the authenticator is supported.
    /// Since this authenticator has no special requirements, it is always supported.
    /// - Returns: `true`
    public override func isSupported(attestation: Attestation) -> Bool {
        return true
    }
    
    /// Deletes all keys associated with this authenticator.
    public override func deleteKeys() async throws {
        let userKeys = try await UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .none {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
}

