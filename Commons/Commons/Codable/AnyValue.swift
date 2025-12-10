//
//  AnyValue.swift
//  Commons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation


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
public struct AnyValue: Codable, @unchecked Sendable {
    
    /// The wrapped value of any type.
    ///
    /// This property holds the actual value that has been type-erased. The value can be
    /// retrieved by casting it to its original type.
    public let value: Any
    
    /// Creates a new `AnyValue` wrapper around the provided value.
    ///
    /// Use this initializer to wrap any value that you want to store in a heterogeneous
    /// collection while maintaining Codable compliance.
    ///
    /// - Parameter value: The value to wrap. Should be one of the supported types:
    ///   Bool, Int, Double, String, Array, Dictionary, or NSNull
    public init(_ value: Any) {
        self.value = value
    }
    
    /// Decodes a value from the given decoder.
    ///
    /// This initializer attempts to decode the value by trying each supported type in order:
    /// 1. Null values (represented as NSNull)
    /// 2. Bool (checked first to prevent decoding as Int 1/0)
    /// 3. Int
    /// 4. Double
    /// 5. String
    /// 6. Array (recursively decoded as [AnyValue])
    /// 7. Dictionary (recursively decoded as [String: AnyValue])
    ///
    /// - Parameter decoder: The decoder to read data from
    /// - Throws: `DecodingError.dataCorrupted` if the value is not one of the supported types
    public init(from decoder: Decoder) throws {
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
    
    /// Encodes the wrapped value to the given encoder.
    ///
    /// This method encodes the value based on its runtime type. Special handling is provided for:
    /// - NSNull: Encoded as a JSON null value
    /// - NSNumber: Properly distinguished between Bool, Int, and Double based on ObjC type
    /// - Bool: Checked first to prevent encoding as Int (1/0)
    /// - Primitive types: Int, Double, String
    /// - Collections: Arrays and Dictionaries (recursively encoded as AnyValue)
    ///
    /// - Parameter encoder: The encoder to write data to
    /// - Throws: `EncodingError.invalidValue` if the value type is not supported
    public func encode(to encoder: Encoder) throws {
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
