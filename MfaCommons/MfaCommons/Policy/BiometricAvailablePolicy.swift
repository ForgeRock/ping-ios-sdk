//
//  BiometricAvailablePolicy.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import LocalAuthentication

///
/// Policy that checks if biometric authentication is available on the device.
///
/// This policy evaluates whether the device has biometric capabilities and
/// if they are properly configured for authentication.
///
/// JSON format: {"biometricAvailable": {}}
///
public struct BiometricAvailablePolicy: MfaPolicy, Sendable {

    public static let policyName = "biometricAvailable"

    public var name: String {
        return Self.policyName
    }

    public init() {}

    public func evaluate(data: [String: Any]?) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if canEvaluate {
            // Biometric authentication is available and working
            return true
        }

        guard let error = error else {
            // Unknown error, consider as non-compliant for security
            return false
        }

        switch error.code {
        case LAError.biometryNotEnrolled.rawValue:
            // No biometric credentials are enrolled, but hardware is available
            // Consider this as non-compliant since user hasn't set up biometrics
            return false

        case LAError.biometryNotAvailable.rawValue:
            // No biometric hardware available
            return false

        case LAError.biometryLockout.rawValue:
            // Biometric authentication is locked out due to too many failed attempts
            // Hardware is available but currently inaccessible
            return false

        case LAError.passcodeNotSet.rawValue:
            // Device passcode is not set, which is required for biometric setup
            return false

        default:
            // Any other error, consider as non-compliant
            return false
        }
    }
}
