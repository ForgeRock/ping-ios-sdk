// 
//  DeviceProfileUtils.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

public struct DeviceProfileUtils {
    
    /// Converts an object to JSON string representation
    /// - Parameters:
    ///   - value: The object to convert to JSON
    ///   - prettyPrinted: Whether to format JSON with indentation
    /// - Returns: JSON string, or empty string if conversion fails
    ///
    /// ## Implementation Notes
    /// - Validates JSON object before serialization
    /// - Handles serialization errors gracefully
    /// - Uses UTF-8 encoding for string conversion
    /// - Returns empty string as fallback for invalid objects
    public static func jsonStringify(value: AnyObject, prettyPrinted: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : []
        
        guard JSONSerialization.isValidJSONObject(value) else {
            return ""
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: options)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}


// MARK: - AnyValue Helper

/// A type-erased wrapper for any Codable value.
///
/// This wrapper allows heterogeneous data types to be stored in the same
/// dictionary while maintaining Codable compliance for JSON serialization.
///
/// ## Supported Types
/// - Primitives: Bool, Int, Double, String
/// - Collections: Arrays and Dictionaries (recursively)
/// - Null values: NSNull representation
///
/// ## Usage
/// ```swift
/// let anyValue = AnyValue("Hello World")
/// let originalValue = anyValue.value as? String
/// ```
struct AnyValue: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            // Check Bool FIRST - otherwise it gets decoded as Int (1/0)
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyValue].self) {
            value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyValue].self) {
            value = dictionary.mapValues(\.value)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode AnyValue - unsupported type"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let number as NSNumber:
                // Handle NSNumber specially to distinguish Bool from Int
                let objCType = String(cString: number.objCType)
                if objCType == "c" || objCType == "B" {
                    // This is a boolean (char type in ObjC)
                    try container.encode(number.boolValue)
                } else if objCType.contains("d") || objCType.contains("f") {
                    // This is a floating point
                    try container.encode(number.doubleValue)
                } else {
                    // This is an integer
                    try container.encode(number.intValue)
                }
        case let bool as Bool:
            // Check Bool FIRST - otherwise it gets encoded as Int (1/0)
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyValue.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyValue.init))
        default:
            let context = EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

