//
//  OidcError.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Enum for OIDC errors.
public enum OidcError: LocalizedError {
    /// An error that occurs during the authorization process.
    /// - Parameters:
    ///   - cause: The underlying error that caused the issue (optional).
    ///   - message: A descriptive message about the error (optional).
    case authorizeError(cause: Error? = nil, message: String? = nil)
  
    /// An error that occurs during network communication.
    /// - Parameters:
    ///   - cause: The underlying error that caused the issue (optional).
    ///   - message: A descriptive message about the error (optional).
    case networkError(cause: Error? = nil, message: String? = nil)
  
    /// An error returned from the API.
    /// - Parameters:
    ///   - code: The HTTP status code of the error.
    ///   - message: A descriptive message about the error.
    case apiError(code: Int, message: String)
  
    /// An unknown or unspecified error.
    /// - Parameters:
    ///   - cause: The underlying error that caused the issue (optional).
    ///   - message: A descriptive message about the error (optional).
    case unknown(cause: Error? = nil, message: String? = nil)
    
    /// Provides a human-readable description of the error.
    /// - Returns: A `String` representing the error message.
    public var errorMessage: String {
        switch self {
        case .authorizeError(cause: let cause, message: let message):
            return "Authorization error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        case .networkError(cause: let cause, message: let message):
            return "Network error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        case .apiError(code: let code, message: let message):
            return "API error: \(code) \(message)"
        case .unknown(cause: let cause, message: let message):
            return "Error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        }
    }
}
