/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import UIKit

/// Configuration for device binding.
public class DeviceBindingConfig {
    /// The signing algorithm to use.
    public var signingAlgorithm: String = "ES256"
    /// The device name.
    public var deviceName: String = UIDevice.current.name
    /// The user key storage configuration.
    public var userKeyStorage = UserKeyStorageConfig()
    /// The biometric authenticator configuration.
    public var biometricAuthenticatorConfig = BiometricAuthenticatorConfig(keyTag: "")
    /// The claims to include in the JWT.
    public var claims: [String: Any] = [:]
    /// A closure to select a user key when multiple are available.
    public var userKeySelector: ([UserKey]) -> UserKey? = { $0.first }
    /// The issue time for the JWT.
    public var issueTime: () -> Date = { Date() }
    /// The not-before time for the JWT.
    public var notBeforeTime: () -> Date = { Date() }
    /// The expiration time for the JWT.
    public var expirationTime: (Int) -> Date = { Date(timeIntervalSinceNow: TimeInterval($0)) }
    
    /// Returns the authenticator for the given type.
    /// - Parameters:
    ///   - type: The type of authenticator.
    ///   - prompt: The prompt to display to the user.
    /// - Returns: The authenticator.
    func authenticator(type: DeviceBindingAuthenticationType, prompt: Prompt) -> DeviceAuthenticator {
        switch type {
        case .biometric:
            return BiometricAuthenticator(config: biometricAuthenticatorConfig)
        case .none:
            return NoneAuthenticator()
        }
    }
    
    /// Returns the user key storage.
    /// - Returns: The user key storage.
    func keyStorage() -> UserKeysStorage {
        return UserKeysStorage(config: userKeyStorage)
    }
}
