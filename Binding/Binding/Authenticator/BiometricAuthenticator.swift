/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import LocalAuthentication

/// An authenticator that uses biometrics (Face ID or Touch ID).
class BiometricAuthenticator: DeviceAuthenticator {
    
    /// The type of authenticator.
    let type: DeviceBindingAuthenticationType = .biometric
    private let config: BiometricAuthenticatorConfig
    
    /// Initializes a new `BiometricAuthenticator`.
    /// - Parameter config: The configuration for the authenticator.
    init(config: BiometricAuthenticatorConfig) {
        self.config = config
    }
    
    /// Registers a new key pair.
    /// - Parameter attestation: The attestation to use.
    /// - Returns: The new key pair.
    func register(attestation: Attestation) async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        return try cryptoKey.generateKeyPair(attestation: attestation)
    }
    
    /// Authenticates the user using biometrics.
    /// - Returns: The private key.
    func authenticate() async throws -> SecKey {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        let reason = "Authenticate to access your keys"
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        
        guard context.canEvaluatePolicy(policy, error: &error) else {
            throw DeviceBindingError.deviceNotSupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    do {
                        let privateKey = try self.getPrivateKey()
                        continuation.resume(returning: privateKey)
                    }
                    catch {
                        continuation.resume(throwing: error)
                    }
                } else if let error = error {
                    continuation.resume(throwing: DeviceBindingError.biometricError(error))
                } else {
                    continuation.resume(throwing: DeviceBindingError.unknown)
                }
            }
        }
    }
    
    /// Checks if the device supports biometrics.
    /// - Parameter attestation: The attestation to use.
    /// - Returns: `true` if the device supports biometrics, `false` otherwise.
    func isSupported(attestation: Attestation) -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Deletes all biometric keys.
    func deleteKeys() async throws {
        let userKeys = try UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .biometric {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    /// Gets the private key from the keychain.
    /// - Returns: The private key.
    private func getPrivateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: config.keyTag.data(using: .utf8) ?? Data(),
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

/// Configuration for the BiometricAuthenticator.
public struct BiometricAuthenticatorConfig {
    /// The key tag to use for the key.
    let keyTag: String
}
