//
//  OidcError.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// An OAuth2 error response carried on the authorization redirect (RFC 6749 §4.1.2.1) —
/// for example `access_denied` when the user declines consent at the authorization server.
///
/// Surfaced as the `cause` of `OidcError.authorizeError` when the browser callback carries
/// `error`/`error_description`/`error_uri` query (or fragment) parameters instead of a code.
public struct OAuthAuthorizationError: Error, Sendable, Equatable {
    /// The OAuth2 `error` code (e.g. `access_denied`, `invalid_request`).
    public let code: String
    /// The optional human-readable `error_description` from the server.
    public let errorDescription: String?
    /// The optional `error_uri` pointing to human-readable documentation.
    public let errorUri: String?

    public init(code: String, errorDescription: String? = nil, errorUri: String? = nil) {
        self.code = code
        self.errorDescription = errorDescription
        self.errorUri = errorUri
    }

    /// A formatted one-line rendering used as the wrapping `OidcError` message.
    var formattedMessage: String {
        var text = code
        if let errorDescription {
            text += ": \(errorDescription)"
        }
        if let errorUri {
            text += " (see \(errorUri))"
        }
        return text
    }
}

/// Enum for OIDC errors.
public enum OidcError: LocalizedError, Sendable {
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
    
    /// An error that occurs because the `OidcClientConfig` is not usable as configured —
    /// for example neither `discoveryEndpoint` nor `openId` was supplied, so the SDK has no
    /// OpenID configuration to work from. The failure is deterministic: retrying without
    /// changing the configuration produces the same error.
    /// - Parameter message: A descriptive message about what is missing or invalid.
    case configurationError(message: String)

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
        case .configurationError(message: let message):
            return "Configuration error: \(message)"
        case .unknown(cause: let cause, message: let message):
            return "Error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        }
    }
    
    /// A localized description of the error, used by `LocalizedError`.
    public var errorDescription: String? { errorMessage }
}
