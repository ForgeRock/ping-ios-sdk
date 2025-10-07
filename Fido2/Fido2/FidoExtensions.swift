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

extension Data {
    /// Returns an array of bytes from the data.
    var bytesArray: [UInt8] {
        return [UInt8](self)
    }
    
    /// Returns a base64url encoded string from the data.
    func base64urlEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    /// Returns a base64url encoded string from the string.
    func base64urlEncodedString() -> String? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        return data.base64urlEncodedString()
    }

    /// Returns a base64 encoded string from the string.
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

/// Converts an array of Int8 to a string.
///
/// - Parameter arr: The array of Int8 to convert.
/// - Returns: A string representation of the array.
func convertInt8ArrToStr(_ arr: [Int8]) -> String {
    return arr.map { String($0) }.joined(separator: ",")
}

/// Converts a base64 string to a base64url string.
///
/// - Parameter base64: The base64 string to convert.
/// - Returns: A base64url encoded string.
func base64ToBase64url(base64: String) -> String {
    return base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
