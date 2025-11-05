//
//  OathKeychainSecurityOptions.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import LocalAuthentication

/// Security options for OATH keychain storage.
/// Provides enhanced security configurations including biometric authentication.
public struct OathKeychainSecurityOptions: Sendable {

    // MARK: - Properties
    
    /// Keychain accessibility level.
    public let accessibility: String

    /// Whether biometric authentication is required.
    public let requireBiometrics: Bool

    /// Whether device passcode is required as fallback.
    public let requireDevicePasscode: Bool

    /// Custom prompt for biometric authentication.
    public let biometricPrompt: String?

    /// Keychain access group for app groups sharing.
    public let accessGroup: String?

    
    // MARK: - Initializers

    /// Creates security options with specified parameters.
    /// - Parameters:
    ///   - accessibility: Keychain accessibility level.
    ///   - requireBiometrics: Whether biometric authentication is required.
    ///   - requireDevicePasscode: Whether device passcode is required as fallback.
    ///   - biometricPrompt: Custom prompt for biometric authentication.
    ///   - accessGroup: Keychain access group for sharing.
    public init(
        accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        requireBiometrics: Bool = false,
        requireDevicePasscode: Bool = false,
        biometricPrompt: String? = nil,
        accessGroup: String? = nil
    ) {
        self.accessibility = accessibility as String
        self.requireBiometrics = requireBiometrics
        self.requireDevicePasscode = requireDevicePasscode
        self.biometricPrompt = biometricPrompt
        self.accessGroup = accessGroup
    }

    
    // MARK: - Predefined Configurations

    /// Default security configuration with device unlock protection.
    public static let standard = OathKeychainSecurityOptions(
        accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )

    /// High security configuration requiring biometric authentication.
    public static let biometric = OathKeychainSecurityOptions(
        accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        requireBiometrics: true,
        requireDevicePasscode: true,
        biometricPrompt: "Access OATH credentials"
    )

    /// Maximum security configuration with biometrics and no fallback.
    public static let biometricOnly = OathKeychainSecurityOptions(
        accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        requireBiometrics: true,
        requireDevicePasscode: false,
        biometricPrompt: "Biometric authentication required for OATH credentials"
    )

    /// Shared keychain configuration for app group sharing.
    /// - Parameter accessGroup: The app group identifier.
    /// - Returns: Security options configured for sharing.
    public static func shared(accessGroup: String) -> OathKeychainSecurityOptions {
        return OathKeychainSecurityOptions(
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            accessGroup: accessGroup
        )
    }

    // MARK: - Internal Methods

    /// Creates keychain query attributes based on these security options.
    /// - Returns: Dictionary of keychain attributes.
    internal func keychainAttributes() -> [String: Any] {
        var attributes: [String: Any] = [
            kSecAttrAccessible as String: accessibility
        ]

        if let accessGroup = accessGroup {
            attributes[kSecAttrAccessGroup as String] = accessGroup
        }

        // Add biometric authentication if required
        if requireBiometrics {
            let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessibility as CFString,
                requireDevicePasscode ? .biometryCurrentSet : .biometryAny,
                nil
            )

            if accessControl != nil {
                attributes[kSecAttrAccessControl as String] = accessControl
                attributes.removeValue(forKey: kSecAttrAccessible as String)
            }
        }

        return attributes
    }

    /// Creates authentication context for biometric operations.
    /// - Returns: LAContext configured for this security level.
    internal func authenticationContext() -> LAContext? {
        guard requireBiometrics else { return nil }

        let context = LAContext()
        if let prompt = biometricPrompt {
            context.localizedReason = prompt
        }
        return context
    }
}
