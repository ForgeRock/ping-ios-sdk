
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
public enum DeviceBindingAuthenticationType: String, Codable {
    /// Biometric authentication (Face ID or Touch ID) is required.
    case biometricOnly = "BIOMETRIC_ONLY"
    /// Biometric authentication (Face ID or Touch ID) with fallback to the device passcode.
    case biometricAllowFallback = "BIOMETRIC_ALLOW_FALLBACK"
    /// Application PIN authentication is required.
    case applicationPin = "APPLICATION_PIN"
    /// No user authentication is required.
    case none = "NONE"
    
    /// Returns the appropriate `DeviceAuthenticator` for the authentication type.
    func getAuthType() -> DeviceAuthenticator {
        switch self {
        case .biometricOnly:
            return BiometricOnlyAuthenticator()
        case .biometricAllowFallback:
            return BiometricAndDeviceCredentialAuthenticator()
        case .applicationPin:
            return ApplicationPinDeviceAuthenticator()
        case .none:
            return NoneAuthenticator()
        }
    }
}
