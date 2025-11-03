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
    /// The signing algorithm to use for the JWS.
    /// The default is `ES512`. Allowed values are "ES256" and "ES512".
    public var signingAlgorithm: String = "ES512"
    #if canImport(UIKit)
    /// The name of the device.
    /// The default is the current device name.
    public var deviceName: String = UIDevice.current.name
    #else
    /// The name of the device.
    /// The default is "Apple".
    public var deviceName: String = "Apple"
    #endif
    /// The configuration for the user key storage.
    public var userKeyStorage = UserKeyStorageConfig()
    /// Custom claims to be included in the JWS.
    public var claims: [String: Any] = [:]
    /// A closure that selects a user key when multiple keys are available for signing.
    /// The default implementation selects the first key in the list.
    public var userKeySelector: ([UserKey]) -> UserKey? = { $0.first }
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
    
    /// The algorithm to be used for signing. It is derived from `signingAlgorithm`.
    internal func getSecKeyAlgorithm() throws -> SecKeyAlgorithm {
        switch signingAlgorithm {
        case "ES256":
            return .ecdsaSignatureMessageX962SHA256
        case "ES512":
            return .ecdsaSignatureMessageX962SHA512
        default:
            throw DeviceBindingError.unsupported(errorMessage: "Unsupported signing algorithm: \(signingAlgorithm). Only ES256 and ES512 are supported.")
        }
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
            let authenticator = type.getAuthType(config: authenticatorConfig)
            authenticator.setPrompt(prompt)
            return authenticator
        }
        return deviceAuthenticator
    }
    
    /// Returns the user key storage.
    /// - Returns: The user key storage.
    func keyStorage() -> UserKeysStorage {
        return UserKeysStorage(config: userKeyStorage)
    }
}

