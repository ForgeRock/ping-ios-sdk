
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// An authenticator that does not require any user interaction.
class NoneAuthenticator: DeviceAuthenticator {
    
    let type: DeviceBindingAuthenticationType = .none
    
    func register(attestation: Attestation) async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        return try cryptoKey.generateKeyPair(attestation: attestation)
    }
    
    func authenticate() async throws -> SecKey {
        return try getPrivateKey()
    }
    
    func isSupported(attestation: Attestation) -> Bool {
        return true
    }
    
    func deleteKeys() async throws {
        let userKeys = try UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .none {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    private func getPrivateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "".data(using: .utf8) ?? Data(),
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
}
