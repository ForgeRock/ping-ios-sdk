//
//  BiometricAndDeviceCredentialAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import LocalAuthentication

/// An authenticator that uses biometrics (Face ID or Touch ID) with a fallback to device credentials (passcode/PIN).
/// This class extends `DefaultDeviceAuthenticator` and provides specific implementations
/// for key generation, authentication, and support checks for this combined authentication type.
public class BiometricDeviceCredentialAuthenticator: DefaultDeviceAuthenticator {
    
    /// The type of authenticator, specifically `.biometricAllowFallback`.
    public override func type() -> DeviceBindingAuthenticationType {
        return .biometricAllowFallback
    }
    
    /// Generates a new cryptographic key pair for biometric and device credential authentication.
    /// The key is stored in the Secure Enclave (if available) and associated with a unique key tag.
    /// - Throws: `CryptoKeyError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    public override func register() async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                            [.biometryCurrentSet, .or, .devicePasscode, .privateKeyUsage],
                                                            nil) else {
            throw DeviceBindingError.unknown
        }
        return try cryptoKey.generateKeyPair(attestation: .none, accessControl: accessControl)
    }
    
    /// - Returns: A `Result` containing the `SecKey` on success, or an `Error` on failure.
    public override func authenticate(keyTag: String) async -> Result<SecKey, Error> {
        // Initialize LAContext for Local Authentication
        let context = LAContext()
        // Customize the cancel button title for the authentication prompt
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        // Check if the device can evaluate the defined policy
        guard context.canEvaluatePolicy(policy, error: &error) else {
            return .failure(DeviceBindingError.deviceNotSupported)
        }
        do {
            let privateKey = try self.getPrivateKey(keyTag: keyTag)
            return .success(privateKey)
        }
        catch {
            // Propagate any errors during private key retrieval
            return .failure(DeviceBindingError.biometricError(error))
        }
    }
    
    /// Checks if the device supports biometric or device credential authentication.
    /// - Parameter attestation: The attestation type (currently ignored).
    /// - Returns: `true` if the device supports the authentication policy, `false` otherwise.
    public override func isSupported(attestation: Attestation) -> Bool {
        let laContext = LAContext()
        var evalError: NSError?
        // Check if the device can evaluate the defined policy
        return laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evalError)
    }
    
    /// Deletes all biometric and device credential keys associated with this authenticator.
    /// It iterates through all stored user keys and deletes those with `.biometricOnly` or `.biometricAllowFallback` authentication types.
    /// - Throws: `CryptoKeyError` if key deletion fails.
    public override func deleteKeys() async throws {
        // Retrieve all stored user keys
        let userKeys = try await UserKeysStorage(config: UserKeyStorageConfig()).findAll()
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
