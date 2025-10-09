//
//  OathType.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Enum representing the different types of OATH credentials.
///
/// OATH (Open Authentication) supports two main types of one-time password algorithms:
/// - **TOTP (Time-based One-Time Password)**: Generates codes based on the current time
/// - **HOTP (HMAC-based One-Time Password)**: Generates codes based on a counter value
///
/// ## Standards Compliance
/// Both algorithms are standardized in RFC specifications and widely supported
/// by authentication systems and mobile authenticator applications.
///
/// - **TOTP**: Implements RFC 6238 (TOTP: Time-Based One-Time Password Algorithm)
/// - **HOTP**: Implements RFC 4226 (HOTP: An HMAC-Based One-Time Password Algorithm)
public enum OathType: String, CaseIterable, Codable, Sendable {
    
    /// Time-based One-Time Password algorithm (RFC 6238).
    ///
    /// TOTP generates codes that are valid for a specific time window (typically 30 seconds).
    /// The algorithm combines the current time with a shared secret to produce a unique code.
    ///
    /// **Characteristics:**
    /// - Codes automatically expire after the time period
    /// - No counter synchronization required
    /// - Resistant to replay attacks
    /// - Requires accurate time synchronization between client and server
    case totp = "totp"

    /// HMAC-based One-Time Password algorithm (RFC 4226).
    ///
    /// HOTP generates codes based on a counter value that increments with each use.
    /// The algorithm combines the counter with a shared secret to produce a unique code.
    ///
    /// **Characteristics:**
    /// - Codes remain valid until used or explicitly invalidated
    /// - Requires counter synchronization between client and server
    /// - No time dependency
    /// - Vulnerable to replay attacks if not properly managed
    case hotp = "hotp"

    /// Creates an OathType from a string representation.
    /// - Parameter string: The string representation (case-insensitive).
    /// - Returns: The corresponding OathType.
    /// - Throws: `OathError.invalidOathType` if the string doesn't match any known type.
    public static func fromString(_ string: String) throws -> OathType {
        switch string.lowercased() {
        case "totp":
            return .totp
        case "hotp":
            return .hotp
        default:
            throw OathError.invalidOathType(string)
        }
    }
}
