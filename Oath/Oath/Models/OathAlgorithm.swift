//
//  OathAlgorithm.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Enum representing the different HMAC algorithms supported for OATH credential generation.
///
/// OATH algorithms use HMAC (Hash-based Message Authentication Code) with different
/// hash functions to generate one-time passwords. The choice of algorithm affects
/// both security strength and computational requirements.
///
/// ## Algorithm Comparison
///
/// | Algorithm | Security | Performance | Digest Size | Recommendation |
/// |-----------|----------|-------------|-------------|----------------|
/// | SHA-1     | Legacy   | Fastest     | 160 bits    | Legacy support only |
/// | SHA-256   | Strong   | Moderate    | 256 bits    |  Industry standard |
/// | SHA-512   | Strongest| Slowest     | 512 bits    | High security needs |
///
/// ## Standards Compliance
///
/// All algorithms implement the HMAC construction as defined in RFC 2104,
/// and are compatible with RFC 4226 (HOTP) and RFC 6238 (TOTP) specifications.
public enum OathAlgorithm: String, CaseIterable, Codable, Sendable {
    
    /// SHA-1 HMAC algorithm (legacy).
    ///
    /// **Security Note**: SHA-1 is cryptographically weak and should only be used
    /// for legacy system compatibility. New implementations should use SHA-256 or SHA-512.
    case sha1 = "SHA1"

    /// SHA-256 HMAC algorithm.
    ///
    /// The standard algorithm for new OATH implementations. Provides a strong balance of
    /// security with good performance characteristics.

    case sha256 = "SHA256"

    /// SHA-512 HMAC algorithm.
    ///
    /// Provides the highest level of cryptographic security but with increased
    /// computational overhead. Suitable for high-security environments.
    case sha512 = "SHA512"

    /// Creates an OathAlgorithm from a string representation.
    /// - Parameter string: The string representation (case-insensitive).
    /// - Returns: The corresponding OathAlgorithm.
    /// - Throws: `OathError.invalidAlgorithm` if the string doesn't match any known algorithm.
    public static func fromString(_ string: String) throws -> OathAlgorithm {
        switch string.uppercased() {
        case "SHA1":
            return .sha1
        case "SHA256":
            return .sha256
        case "SHA512":
            return .sha512
        default:
            throw OathError.invalidAlgorithm(string)
        }
    }
    
}
