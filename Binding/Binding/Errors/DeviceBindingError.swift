//
//  DeviceBindingError.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// An enum representing the possible errors that can occur during the device binding and signing process.
public enum DeviceBindingError: Error, Equatable {
    /// Authentication with the user failed.
    case authenticationFailed
    /// The device does not support the required authentication method (e.g., biometrics).
    case deviceNotSupported
    /// No key was found for the user, so the device is not registered.
    case deviceNotRegistered
    /// A custom claim conflicts with a reserved JWT claim.
    case invalidClaim
    /// An error occurred during biometric authentication.
    case biometricError(Error)
    /// The user cancelled the operation.
    case userCanceled
    /// An unknown or unexpected error occurred.
    case unknown
    
    public static func == (lhs: DeviceBindingError, rhs: DeviceBindingError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed, .authenticationFailed):
            return true
        case (.deviceNotSupported, .deviceNotSupported):
            return true
        case (.deviceNotRegistered, .deviceNotRegistered):
            return true
        case (.invalidClaim, .invalidClaim):
            return true
        case (.userCanceled, .userCanceled):
            return true
        case (.unknown, .unknown):
            return true
        case (.biometricError(let lhsError), .biometricError(let rhsError)):
            return (lhsError as NSError).domain == (rhsError as NSError).domain &&
                       (lhsError as NSError).code == (rhsError as NSError).code
        default:
            return false
        }
    }
}
