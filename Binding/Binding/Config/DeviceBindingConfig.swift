//
//  DeviceBindingConfig.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Configuration for device binding.
/// This class allows you to customize the behavior of the device binding and signing process.
public class DeviceBindingConfig {
    #if canImport(UIKit)
    /// Helper private variable for deviceName
    private var _deviceName: String?
    /// The name of the device.
    /// The default is the current device name.
    public var deviceName: String {
        get {
            if let name = _deviceName {
                return name
            }
            if Thread.isMainThread {
                return UIDevice.current.name
            } else {
                return DispatchQueue.main.sync {
                    UIDevice.current.name
                }
            }
        }
        set {
            _deviceName = newValue
        }
    }
    #else
    /// The name of the device.
    /// The default is "Apple".
    public var deviceName: String = "Apple"
    #endif
    /// The configuration for the user key storage.
    public var userKeyStorage = UserKeyStorageConfig()
    /// Custom claims to be included in the JWS.
    public var claims: [String: Any] = [:]
    #if canImport(UIKit)
    /// A custom user key selector for choosing from multiple keys.
    /// The default implementation uses a system alert.
    public var userKeySelector: UserKeySelector = DefaultUserKeySelector()
    #endif
    /// A closure that returns the issue time for the JWS.
    /// The default implementation returns the current date.
    public var issueTime: () -> Date = { Date() }
    /// A closure that returns the not-before time for the JWS.
    /// The default implementation returns the current date.
    public var notBeforeTime: () -> Date = { Date() }
    /// A closure that returns the expiration time for the JWS.
    /// The default implementation returns the current date plus the given timeout in seconds.
    public var expirationTime: (Int) -> Date = { Date(timeIntervalSinceNow: TimeInterval($0)) }
    /// The timeout for the operation.
    public var timeout: Int = 60
    /// The attestation option.
    public var attestation: Attestation = .none
    /// The type of authentication to be used.
    public var deviceBindingAuthenticationType: DeviceBindingAuthenticationType = .none
    /// The custom device authenticator to be used.
    public var deviceAuthenticator: DeviceAuthenticator?
    /// The custom authenticator configuration to be used.
    public var authenticatorConfig: AuthenticatorConfig?
    
    /// The algorithm to be used for signing. Always uses ES256 with P-256 curve.
    internal func getSecKeyAlgorithm() -> SecKeyAlgorithm {
        return .ecdsaSignatureMessageX962SHA256
    }
    
    /// Gets the key size in bits. Always returns 256 for P-256 curve (ES256).
    internal func getKeySizeInBits() -> Int {
        return 256
    }
    
    /// Initializes a new `DeviceBindingConfig`.
    public init() { }
    
    /// Returns the authenticator for the given type.
    /// - Parameters:
    ///   - type: The type of authenticator.
    ///   - prompt: The prompt to display to the user.
    /// - Returns: The authenticator.
    func authenticator(type: DeviceBindingAuthenticationType, prompt: Prompt) -> DeviceAuthenticator {
        /// If a custom device authenticator is provided, use it.
        guard let deviceAuthenticator = deviceAuthenticator else {
            #if canImport(UIKit)
            // If no custom config is provided, create a default one with the appropriate key size
            var config = authenticatorConfig
            if config == nil {
                switch type {
                case .biometricOnly, .biometricAllowFallback:
                    config = BiometricAuthenticatorConfig()
                case .applicationPin:
                    config = AppPinConfig()
                case .none:
                    break
                }
            }
            
            let authenticator = type.getAuthType(config: config)
            authenticator.setPrompt(prompt)
            return authenticator
            #else
            let authenticator = type.getAuthType()
            authenticator.setPrompt(prompt)
            return authenticator
            #endif
        }
        return deviceAuthenticator
    }
    
    /// Returns the user key storage.
    /// - Returns: The user key storage.
    func keyStorage() -> UserKeysStorage {
        return UserKeysStorage(config: userKeyStorage)
    }
}

