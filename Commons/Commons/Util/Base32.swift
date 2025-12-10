//
//  Base32.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Base32 encoding and decoding utilities for OATH secret keys.
/// Implements RFC 4648 Base32 encoding specification.
enum Base32 {

    // MARK: - Constants

    /// Base32 alphabet as defined in RFC 4648
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    /// Mapping from Base32 characters to their 5-bit values
    private static let decodeTable: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (index, char) in alphabet.enumerated() {
            table[char] = UInt8(index)
        }
        return table
    }()

    
    // MARK: - Public Methods

    /// Decodes a Base32 encoded string to Data.
    /// - Parameters:
    ///   - base32String: The Base32 encoded string to decode.
    ///   - strict: If true, requires proper padding (multiple of 8 chars). Default is false for compatibility.
    /// - Returns: The decoded Data, or nil if the string is invalid.
    static func decode(_ base32String: String, strict: Bool = false) -> Data? {
        // Remove whitespace and convert to uppercase
        let cleanString = base32String
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // Security: Reject extremely long inputs (DoS protection)
        // Use 9999 as the limit to reject inputs >= 10000
        guard cleanString.count < 10000 else {
            return nil
        }

        // Security: Validate padding
        // Padding must only appear at the end (if at all)
        if let firstPaddingIndex = cleanString.firstIndex(of: "=") {
            let paddingStart = cleanString.distance(from: cleanString.startIndex, to: firstPaddingIndex)
            let paddingSubstring = cleanString[firstPaddingIndex...]

            // All characters after first padding must also be padding
            guard paddingSubstring.allSatisfy({ $0 == "=" }) else {
                return nil // Padding in middle or invalid padding pattern
            }

            // Validate padding length (RFC 4648: padding to make length multiple of 8)
            let paddingLength = paddingSubstring.count
            let totalLength = cleanString.count
            guard totalLength % 8 == 0 else {
                return nil // Invalid padding - total length must be multiple of 8
            }

            // Padding can only be 0, 1, 3, 4, or 6 characters (based on RFC 4648 Base32)
            let validPaddingLengths: Set<Int> = [0, 1, 3, 4, 6]
            guard validPaddingLengths.contains(paddingLength) else {
                return nil // Invalid padding length
            }
        }

        // Security: In strict mode, require proper padding
        // The input string (before removing padding) must be a multiple of 8 characters
        // This prevents accepting malformed or truncated Base32 strings
        if strict {
            guard cleanString.count % 8 == 0 || cleanString.isEmpty else {
                return nil // Improperly padded Base32 string
            }
        }

        // Remove padding characters
        let trimmedString = cleanString.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        // Check if string is empty or only padding
        guard !trimmedString.isEmpty else {
            // In strict mode, reject empty/all-padding strings
            // In lenient mode, return empty Data for backward compatibility
            return strict ? nil : Data()
        }

        // Validate characters
        for char in trimmedString {
            guard decodeTable[char] != nil else {
                return nil // Invalid character found
            }
        }

        var result = Data()
        var buffer: UInt64 = 0
        var bitsAccumulated = 0

        for char in trimmedString {
            guard let value = decodeTable[char] else {
                return nil // This shouldn't happen due to validation above
            }

            buffer = (buffer << 5) | UInt64(value)
            bitsAccumulated += 5

            // Extract complete bytes (8 bits at a time)
            if bitsAccumulated >= 8 {
                bitsAccumulated -= 8
                let byte = UInt8((buffer >> bitsAccumulated) & 0xFF)
                result.append(byte)
            }
        }

        return result
    }

    /// Encodes Data to a Base32 string.
    /// - Parameter data: The data to encode.
    /// - Returns: The Base32 encoded string.
    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else {
            return ""
        }

        var result = ""
        var buffer: UInt64 = 0
        var bitsAccumulated = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsAccumulated += 8

            // Extract 5-bit groups
            while bitsAccumulated >= 5 {
                bitsAccumulated -= 5
                let index = Int((buffer >> bitsAccumulated) & 0x1F)
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }

        // Handle remaining bits
        if bitsAccumulated > 0 {
            let index = Int((buffer << (5 - bitsAccumulated)) & 0x1F)
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }

        // Add padding
        let paddingLength = (8 - (result.count % 8)) % 8
        result += String(repeating: "=", count: paddingLength)

        return result
    }
}


// MARK: - Data Extension

/// Extension to Data for convenient Base32 operations
extension Data {

    /// Creates a Data instance from a Base32 encoded string.
    /// - Parameter base32String: The Base32 encoded string.
    /// - Returns: The decoded Data, or nil if the string is invalid.
    public init?(base32Encoded base32String: String) {
        guard let decoded = Base32.decode(base32String) else {
            return nil
        }
        self = decoded
    }

    /// Returns the Base32 encoded string representation of this data.
    /// - Returns: The Base32 encoded string.
    public func base32EncodedString() -> String {
        return Base32.encode(self)
    }
}
