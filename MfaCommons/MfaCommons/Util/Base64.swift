//
//  Base64.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Utility class for Base64 encoding and decoding.
/// Provides methods to encode data to a Base64 string and decode a Base64 string back to data.
/// Supports standard and URL-safe Base64 variants.
public class Base64: @unchecked Sendable {
    
    // MARK: - Public Methods
    
    
    /// Checks if a string is Base64 encoded.
    ///
    /// - Parameter value: The string to check.
    /// - Returns: `true` if the string is Base64 encoded, `false` otherwise.
    public static func isBase64Encoded(_ value: String) -> Bool {
        // Try standard Base64 first
        if Data(base64Encoded: value) != nil {
            return true
        }

        // Try URL-safe Base64 with padding normalization
        let paddedValue = addBase64Padding(value)
        let urlSafeValue = paddedValue
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        return Data(base64Encoded: urlSafeValue) != nil
    }

    /// Decodes a Base64 encoded string.
    ///
    /// - Parameter value: The Base64 encoded string.
    /// - Returns: The decoded string.
    /// - Throws: `UriParseError.invalidBase64` if the string is not valid Base64.
    public static func decodeBase64(_ value: String) throws -> String {
        guard let data = Data(base64Encoded: value) else {
            throw Base64Error.invalidBase64(value)
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw Base64Error.invalidBase64String(value)
        }
        return string
    }

    /// Decodes a Base64 URL encoded string.
    ///
    /// - Parameter value: The Base64 URL encoded string.
    /// - Returns: The decoded string.
    /// - Throws: `UriParseError.invalidBase64` if the string is not valid Base64.
    public static func decodeBase64Url(_ value: String) throws -> String {
        // Convert URL-safe Base64 to standard Base64
        let paddedValue = addBase64Padding(value)
        let standardBase64 = paddedValue
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: standardBase64) else {
            throw Base64Error.invalidBase64(value)
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw Base64Error.invalidBase64String(value)
        }
        return string
    }

    /// Decodes a Base64 URL encoded string to Data.
    ///
    /// - Parameter base64URLString: The Base64 URL encoded string.
    /// - Returns: The decoded Data, or `nil` if decoding fails.
    public static func decodeBase64UrlToData(_ base64URLString: String) -> Data? {
        // Convert base64URL to standard base64
        var base64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
    
    /// Encodes a string as Base64.
    ///
    /// - Parameter value: The string to encode.
    /// - Returns: The Base64 encoded string.
    public static func encodeBase64(_ value: String) -> String {
        let data = Data(value.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Recodes a Base64 URL encoded value to a standard Base64 encoded value without URL-safe characters.
    ///
    /// - Parameter value: The Base64 URL encoded string.
    /// - Returns: The recoded standard Base64 string.
    /// - Throws: `UriParseError.invalidBase64` if the string is not valid Base64.
    public static func recodeBase64NoWrapUrlSafeValueToNoWrap(_ value: String) throws -> String {
        // First decode from URL-safe Base64
        let decodedString = try decodeBase64Url(value)
        // Then encode as standard Base64
        let data = Data(decodedString.utf8)
        return data.base64EncodedString()
    }

    /// Recodes a Base64 encoded value to a URL-safe Base64 encoding without padding.
    ///
    /// - Parameter value: The Base64 encoded string.
    /// - Returns: The recoded URL-safe Base64 string.
    /// - Throws: `UriParseError.invalidBase64` if the string is not valid Base64.
    public static func recodeBase64NoWrapValueToUrlSafeNoWrap(_ value: String) throws -> String {
        // First decode from standard Base64
        let decodedString = try decodeBase64(value)
        // Then encode as URL-safe Base64
        return encodeBase64(decodedString)
    }

    
    // MARK: - Private Helper Methods

    private static func addBase64Padding(_ value: String) -> String {
        let remainder = value.count % 4
        if remainder > 0 {
            return value + String(repeating: "=", count: 4 - remainder)
        }
        return value
    }
}


// MARK: - Error Types

/// Errors that can occur during URI parsing.
public enum Base64Error: Error, LocalizedError, Sendable {
    case invalidBase64(String)
    case invalidBase64String(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBase64(let value):
            return "Invalid Base64 string: \(value)"
        case .invalidBase64String(let value):
            return "Base64 decoded data is not a valid UTF-8 string: \(value)"
        }
    }
}


// MARK: - Data Extension for Base64URL

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}


// MARK: - String Extension for Base64 and URL Utilities

//  String class extension for FRCore utilities
extension String {
    
    /// Encodes current String into Base64 encoded string
    /// - Returns: Base64 encoded string
    public func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }
    
    /// Decodes current String into Base64 decoded string
    /// - Returns: Base64 decoded string
    public func base64URLSafeEncoded() -> String? {
        return data(using: .utf8)?.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    
    /// Decodes current Base64 encoded string
    public func base64Decoded() -> String? {
        let padded = self.base64Pad()
        guard let data = Data(base64Encoded: padded) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Validates whether current String is base64 encoded or not
    public func isBase64Encoded() -> Bool {
        if let _ = Data(base64Encoded: self) {
            return true
        }
        return false
    }
    
    /// Decodes URL string
    /// - Returns: URL safe decoded bytes array
    public func decodeURL() -> Data? {
        let fixed = self.urlSafeDecoding()
        return fixed.decodeBase64()
    }
    
    /// Adds base64 pad
    /// - Returns: Base64 pad added string
    public func base64Pad() -> String {
        return self.padding(toLength: ((self.count+3)/4)*4, withPad: "=", startingAt: 0)
    }
    
    /// Decodes base64 and converts it into bytes array
    /// - Returns: Base64 decoded bytes array
    public func decodeBase64() -> Data? {
        let padded = self.base64Pad()
        let encodedData = Data(base64Encoded: padded)
        return encodedData
    }
    
    /// Converts String to URL safe decoded string
    /// - Returns: URL safe decoded string
    public func urlSafeDecoding() -> String {
        let str = self.replacingOccurrences(of: "-", with: "+")
        return str.replacingOccurrences(of: "_", with: "/")
    }
    
    /// Converts String to URL safe encoded string
    /// - Returns: URL safe encoded string
    public func urlSafeEncoding() -> String {
        return self.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    
}
