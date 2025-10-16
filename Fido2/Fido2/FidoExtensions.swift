//
//  FidoExtensions.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

// MARK: - Data Extensions

extension Data {
    /// Returns an array of bytes from the `Data` object.
    var bytesArray: [UInt8] {
        return [UInt8](self)
    }
    
    /// Returns a Base64URL encoded string.
    ///
    /// This encoding is URL-safe and does not include padding.
    func base64urlEncodedString() -> String {
        var base64 = self.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.replacingOccurrences(of: "=", with: "")
        return base64
    }
}

// MARK: - String Extensions

extension String {
    /// Returns a Base64URL encoded string from the string.
    func base64urlEncodedString() -> String? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        return data.base64urlEncodedString()
    }
    
    /// Returns a Base64 encoded string from the string.
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

// MARK: - Helper Functions

/// Converts an array of `Int8` to a comma-separated string.
///
/// - Parameter arr: The array of `Int8` to convert.
/// - Returns: A string representation of the array.
func convertInt8ArrToStr(_ arr: [Int8]) -> String {
    return arr.map { String($0) }.joined(separator: FidoConstants.INT_SEPARATOR)
}

/// Converts a Base64 string to a Base64URL string.
///
/// - Parameter base64: The Base64 string to convert.
/// - Returns: A Base64URL encoded string.
func base64ToBase64url(base64: String) -> String {
    return base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
