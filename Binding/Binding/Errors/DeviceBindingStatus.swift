//
//  DeviceBindingStatus.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Constants for the client error strings.
struct BindingStatusConstants {
    static let timeout = "Timeout"
    static let abort = "Abort"
    static let unsupported = "Unsupported"
    static let clientNotRegistered = "ClientNotRegistered"
}

/// An enum representing the status of a device binding operation, which can be used to convey more specific information about the outcome of a binding or signing attempt.
public enum DeviceBindingStatus: Error {
    /// The operation timed out.
    case timeout
    /// The user aborted the operation.
    case abort
    /// The operation is not supported on this device.
    case unsupported(errorMessage: String?)
    /// The client is not registered.
    case clientNotRegistered
    /// The user is not authorized.
    case unAuthorize
    /// The custom claims are invalid.
    case invalidCustomClaims
    
    /// A client error string that can be sent to the server.
    public var clientError: String {
        switch self {
        case .timeout:
            return BindingStatusConstants.timeout
        case .abort:
            return BindingStatusConstants.abort
        case .unsupported:
            return BindingStatusConstants.unsupported
        case .clientNotRegistered:
            return BindingStatusConstants.clientNotRegistered
        case .unAuthorize:
            return BindingStatusConstants.abort
        case .invalidCustomClaims:
            return BindingStatusConstants.abort
        }
    }
    
    /// A user-facing error message.
    public var errorMessage: String {
        switch self {
        case .timeout:
            return "Authentication Timeout"
        case .abort:
            return "User Terminates the Authentication"
        case .unsupported(let errorMessage):
            return errorMessage ?? "Device not supported. Please verify the biometric or Pin settings"
        case .clientNotRegistered:
            return "PublicKey or PrivateKey Not found in Device"
        case .unAuthorize:
            return "Invalid Credentials"
        case .invalidCustomClaims:
            return "Invalid Custom Claims"
        }
    }
}
