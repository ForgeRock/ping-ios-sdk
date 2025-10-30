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
    /// The default is `ES256`.
    public var signingAlgorithm: String = "ES256"
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
    
    /// Returns the authenticator for the given type.
    /// - Parameters:
    ///   - type: The type of authenticator.
    ///   - prompt: The prompt to display to the user.
    /// - Returns: The authenticator.
    func authenticator(type: DeviceBindingAuthenticationType, prompt: Prompt) -> DeviceAuthenticator {
        let authenticator = type.getAuthType()
        authenticator.setPrompt(prompt)
        return authenticator
    }
    
    /// Returns the user key storage.
    /// - Returns: The user key storage.
    func keyStorage() -> UserKeysStorage {
        return UserKeysStorage(config: userKeyStorage)
    }
}

