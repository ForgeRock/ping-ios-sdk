
//
//  DeviceBindingAuthenticationType.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// An enum representing the type of device binding authentication.
public enum DeviceBindingAuthenticationType: String, Codable, Sendable {
    /// Biometric authentication (Face ID or Touch ID) is required.
    case biometricOnly = "BIOMETRIC_ONLY"
    /// Biometric authentication (Face ID or Touch ID) with fallback to the device passcode.
    case biometricAllowFallback = "BIOMETRIC_ALLOW_FALLBACK"
    /// Application PIN authentication is required.
    case applicationPin = "APPLICATION_PIN"
    /// No user authentication is required.
    case none = "NONE"
    
    #if canImport(UIKit)
    /// Returns the appropriate `DeviceAuthenticator` for the authentication type.
    func getAuthType(pinCollector: PinCollector? = nil) -> DeviceAuthenticator {
        switch self {
        case .biometricOnly:
            return BiometricOnlyAuthenticator()
        case .biometricAllowFallback:
            return BiometricDeviceCredentialAuthenticator()
        case .applicationPin:
            return AppPinAuthenticator(pinCollector: pinCollector ?? DefaultPinCollector())
        case .none:
            return NoneAuthenticator()
        }
    }
    #else
    /// Returns the appropriate `DeviceAuthenticator` for the authentication type.
    func getAuthType(pinCollector: PinCollector? = nil) -> DeviceAuthenticator {
        switch self {
        case .biometricOnly:
            return BiometricOnlyAuthenticator()
        case .biometricAllowFallback:
            return BiometricDeviceCredentialAuthenticator()
        case .applicationPin:
            fatalError("Application PIN is not supported on this platform.")
        case .none:
            return NoneAuthenticator()
        }
    }
    #endif
}
