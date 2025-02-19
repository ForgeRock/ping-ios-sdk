//
//  IdpExceptions.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A class representing IdpExceptions
public enum IdpExceptions: LocalizedError {
    
    /// An unsupportedIdpException
    /// - Parameters:
    ///   - message: A descriptive message about the error (optional).
    case unsupportedIdpException(message: String? = nil)
    
    /// An IllegalArgumentException
    /// - Parameters:
    ///   - message: A descriptive message about the error (optional).
    case illegalArgumentException(message: String? = nil)
    
    /// An IllegalStateException
    /// - Parameters:
    ///   - message: A descriptive message about the error (optional).
    case illegalStateException(message: String? = nil)
    
    /// An idpCanceledException
    /// - Parameters:
    ///   - message: A descriptive message about the error (optional).
    case idpCanceledException(message: String? = nil)
    
    /// Provides a human-readable description of the error.
    /// - Returns: A `String` representing the error message.
    public var errorMessage: String {
        switch self {
        case .unsupportedIdpException(message: let message):
            return "Unsupported Idp Exception: \(message ?? "Unknown")"
        case .idpCanceledException(message: let message):
            return "Idp Canceled Exception: \(message ?? "Unknown")"
        case .illegalArgumentException(message: let message):
            return "illegalArgumentException Idp Exception: \(message ?? "Unknown")"
        case .illegalStateException(message: let message):
            return "illegalStateException Idp Exception: \(message ?? "Unknown")"
        }
    }
}
