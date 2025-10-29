
//
//  BiometricOnlyAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import LocalAuthentication
import PingJourney

/// An authenticator that uses biometrics (Face ID or Touch ID) for user authentication.
/// This class extends `DefaultDeviceAuthenticator` and provides specific implementations
/// for biometric-only key generation, authentication, and support checks.
class BiometricOnlyAuthenticator: DefaultDeviceAuthenticator {
    
    /// The type of authenticator, specifically `.biometricOnly`.
    override func type() -> DeviceBindingAuthenticationType {
        return .biometricOnly
    }
    
    /// Generates a new cryptographic key pair for biometric authentication.
    /// The key is stored in the Secure Enclave (if available) and associated with a unique key tag.
    /// - Throws: `CryptoKeyError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    override func generateKeys() throws -> KeyPair {
        // Create a new CryptoKey with a unique identifier
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                            [.biometryCurrentSet, .privateKeyUsage],
                                                            nil) else {
            throw DeviceBindingError.unknown
        }
        return try cryptoKey.generateKeyPair(attestation: .none, accessControl: accessControl)
    }
    
    /// Authenticates the user using biometrics (Face ID or Touch ID).
    /// This method prompts the user for biometric verification to access the private key.
    /// - Parameter keyTag: The unique identifier of the private key to be accessed.
    /// - Returns: The `SecKey` representing the private key if authentication is successful.
    /// - Throws:
    ///   - `DeviceBindingError.deviceNotSupported` if the device does not support biometrics.
    ///   - `DeviceBindingError.biometricError` if biometric authentication fails.
    ///   - `DeviceBindingError.unknown` for other unexpected errors.
    override func authenticate(keyTag: String) async throws -> SecKey {
        // Initialize LAContext for Local Authentication
        let context = LAContext()
        // Customize the cancel button title for the biometric prompt
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        // Determine the reason string for the biometric prompt
        let reason = prompt?.description ?? "Authenticate to access your keys"
        // Define the biometric authentication policy
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        
        // Check if the device can evaluate the biometric policy
        guard context.canEvaluatePolicy(policy, error: &error) else {
            throw DeviceBindingError.deviceNotSupported
        }
        
        do {
            let privateKey = try self.getPrivateKey(keyTag: keyTag)
            return privateKey
        }
        catch {
            throw DeviceBindingError.biometricError(error)
        }
    }
    
    /// Checks if the device supports biometrics for authentication.
    /// - Parameter attestation: The attestation type (currently ignored).
    /// - Returns: `true` if the device supports biometric authentication, `false` otherwise.
    override func isSupported(attestation: Attestation) -> Bool {
        let context = LAContext()
        var error: NSError?
        // Check if the device can evaluate the biometric policy
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Deletes all biometric keys associated with this authenticator.
    /// It iterates through all stored user keys and deletes those with `.biometricOnly` or `.biometricAllowFallback` authentication types.
    /// - Throws: `CryptoKeyError` if key deletion fails.
    override func deleteKeys() async throws {
        // Retrieve all stored user keys
        let userKeys = try UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            // Delete key pairs for biometric authentication types
            if userKey.authType == .biometricOnly || userKey.authType == .biometricAllowFallback {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    /// Retrieves the private key from the Keychain using its unique key tag.
    /// - Parameter keyTag: The unique identifier of the private key to retrieve.
    /// - Returns: The `SecKey` representing the private key.
    /// - Throws: `DeviceBindingError.deviceNotRegistered` if the key is not found in the Keychain.
    private func getPrivateKey(keyTag: String) throws -> SecKey {
        // Define the query to search for the private key in the Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        // Perform the Keychain query
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        // Check the status of the query and return the private key or throw an error
        guard status == errSecSuccess, let item = item else {
            throw DeviceBindingError.deviceNotRegistered
        }
        return (item as! SecKey)
    }
}

