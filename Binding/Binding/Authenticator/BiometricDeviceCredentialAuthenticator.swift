//
//  BiometricAndDeviceCredentialAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import LocalAuthentication
import PingJourneyPlugin
import PingOrchestrate

/// An authenticator that uses biometrics (Face ID or Touch ID) with a fallback to device credentials (passcode/PIN).
///
/// This authenticator supports the `BIOMETRIC_ALLOW_FALLBACK` policy, allowing authentication
/// via either biometrics (Face ID / Touch ID) or device passcode.
///
/// ## Security Model
///
/// Unlike `BiometricOnlyAuthenticator` which uses `.biometryCurrentSet` to have the Secure Enclave
/// hardware-invalidate keys when biometric enrollment changes, this class uses a dynamic
/// access control policy:
/// - **Biometrics enrolled**: `.biometryAny OR .devicePasscode` — allows both authentication methods.
/// - **No biometrics enrolled**: `.devicePasscode` only — avoids Secure Enclave key creation failure
///   on devices that have a passcode set but no Face ID / Touch ID registered.
///
/// Because `.biometryAny` does not invalidate keys on biometric enrollment changes at the
/// hardware level, this class compensates with a software-level check using
/// `LAContext.evaluatedPolicyDomainState`. The biometric domain state is captured at bind time
/// and stored in the `UserKey`. During signing, the stored state is compared against the current
/// state — if they differ (e.g., a fingerprint was added or removed), the keys are deleted and
/// re-binding is required by throwing `.deviceNotRegistered`.
///
/// ## Backward Compatibility
///
/// For `UserKey` instances created before this change (i.e., without a stored `biometricDomainState`),
/// the enrollment check is skipped and signing proceeds normally. This ensures existing bindings
/// are not broken on SDK update. Only keys created after the update will enforce the biometric
/// domain state check.
///
public class BiometricDeviceCredentialAuthenticator: DefaultDeviceAuthenticator {
    
    private let config: BiometricAuthenticatorConfig
    
    /// Initializes the authenticator with a `BiometricAuthenticatorConfig`.
    /// - Parameter config: The configuration object for the authenticator.
    public init(config: BiometricAuthenticatorConfig) {
        self.config = config
        super.init()
    }
    
    /// The type of authenticator, specifically `.biometricAllowFallback`.
    public override func type() -> DeviceBindingAuthenticationType {
        return .biometricAllowFallback
    }
    
    /// Generates a new cryptographic key pair for biometric and device credential authentication.
    /// The key is stored in the Secure Enclave (if available) and associated with a unique key tag.
    ///
    /// Access control flags are dynamically selected based on biometric availability:
    /// - When biometrics are enrolled: `.biometryAny OR .devicePasscode` — allows both methods.
    /// - When only passcode is set: `.devicePasscode` only — avoids Secure Enclave rejecting
    ///   key creation when biometry flags are present but no biometrics are enrolled.
    ///
    /// - Throws: `DeviceBindingError.unknown` if access control creation fails, or a `CryptoKey` error if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    public override func register() async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: config.keyTag)
        let laContext = LAContext()
        let biometricsAvailable = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let flags: SecAccessControlCreateFlags = biometricsAvailable
            ? [.biometryAny, .or, .devicePasscode, .privateKeyUsage]
            : [.devicePasscode, .privateKeyUsage]
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                            flags,
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
    /// - Note: Always returns `false` on simulator — biometric keys require Secure Enclave
    ///         to enforce the authentication challenge. Without it the key is accessible
    ///         with no user verification, which is equivalent to the NONE type.
    public override func isSupported(attestation: Attestation) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let laContext = LAContext()
        var evalError: NSError?
        // Check if the device can evaluate the defined policy
        return laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evalError)
        #endif
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
    
    /// Returns the current biometric domain state from LAContext.
    /// Used to detect biometric enrollment changes between bind and sign operations.
    /// - Returns: The evaluated policy domain state data, or `nil` if biometrics are not enrolled.
    public func biometricDomainState() -> Data? {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.evaluatedPolicyDomainState
    }
    
    /// Override sign to validate biometric enrollment has not changed since binding.
    /// If biometrics were enrolled at bind time and the enrollment has since changed,
    /// the keys are deleted and `.deviceNotRegistered` is thrown to trigger re-binding.
    public override func sign(params: UserKeySigningParameters, journey: Journey?) throws -> String {
        if let storedState = params.userKey.biometricDomainState {
            let currentState = biometricDomainState()
            if currentState != storedState {
                try? CryptoKey(keyTag: params.userKey.keyTag).deleteKeyPair()
                throw DeviceBindingError.deviceNotRegistered
            }
        }
        return try super.sign(params: params, journey: journey)
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
