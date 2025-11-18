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
    /// The operation timed out.
    case timeout
    /// An unknown or unexpected error occurred.
    case unknown
    /// An unsupported error.
    case unsupported(errorMessage: String)
    
    public func toClientError() -> String {
        switch self {
        case .deviceNotRegistered:
            return DeviceBindingStatus.clientNotRegistered.clientError
        case .authenticationFailed, .invalidClaim, .biometricError, .userCanceled, .unknown:
            return DeviceBindingStatus.abort.clientError
        case .timeout:
            return DeviceBindingStatus.timeout.clientError
        case .deviceNotSupported:
            return DeviceBindingStatus.unsupported(errorMessage: "Device not supported").clientError
        case .unsupported(let errorMessage):
            return DeviceBindingStatus.unsupported(errorMessage: errorMessage).clientError
        }
    }
    
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
        case (.biometricError(let lhsError), .biometricError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.userCanceled, .userCanceled):
            return true
        case (.timeout, .timeout):
            return true
        case (.unknown, .unknown):
            return true
        case (.unsupported(let lhsError), .unsupported(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
