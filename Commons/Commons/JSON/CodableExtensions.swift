//
//  CodableExtensions.swift
//  PingCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A dynamic coding key implementation that allows encoding and decoding of arbitrary JSON keys.
///
/// This structure provides flexibility when working with JSON data that contains dynamic or unknown keys
/// at compile time, supporting both string and integer-based keys.
public struct JSONCodingKeys: CodingKey {
    /// The string representation of the coding key.
    ///
    /// This property contains the key name as it appears in the JSON data.
    public var stringValue: String
    
    /// The integer representation of the coding key, if applicable.
    ///
    /// This optional property is used when the key represents an array index
    /// or other integer-based identifier in the JSON structure.
    public var intValue: Int?

    /// Creates a coding key from a string value.
    /// - Parameter stringValue: The string value of the key
    public init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    /// Creates a coding key from an integer value.
    /// - Parameter intValue: The integer value of the key
    public init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

//MARK:- Decoding Extensions

/// Extensions for `KeyedDecodingContainer` to support decoding of dynamic dictionaries and arrays
/// with `Sendable` values, enabling flexible JSON parsing with unknown structures.
extension KeyedDecodingContainer {
    
    /// Decodes a dictionary with string keys and `Sendable` values for a given key.
    ///
    /// - Parameters:
    ///   - type: The type of dictionary to decode
    ///   - key: The coding key to decode from
    /// - Returns: A dictionary with string keys and `Sendable` values
    /// - Throws: `DecodingError` if the value cannot be decoded
    public func decode(_ type: [String: any Sendable].Type, forKey key: K) throws -> [String: any Sendable] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    /// Decodes an array of dictionaries with string keys and `Sendable` values for a given key.
    ///
    /// - Parameters:
    ///   - type: The type of array of dictionaries to decode
    ///   - key: The coding key to decode from
    /// - Returns: An array of dictionaries with string keys and `Sendable` values
    /// - Throws: `DecodingError` if the value cannot be decoded
    public func decode(_ type: [[String: any Sendable]].Type, forKey key: K) throws -> [[String: any Sendable]] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        if let decodedData = try container.decode([any Sendable].self) as? [[String: any Sendable]] {
            return decodedData
        } else {
            return []
        }
    }

    /// Decodes a dictionary with string keys and `Sendable` values if present for a given key.
    ///
    /// - Parameters:
    ///   - type: The type of dictionary to decode
    ///   - key: The coding key to decode from
    /// - Returns: An optional dictionary with string keys and `Sendable` values, or `nil` if the key is not present or the value is null
    /// - Throws: `DecodingError` if the value cannot be decoded
    public func decodeIfPresent(_ type: [String: any Sendable].Type, forKey key: K) throws -> [String: any Sendable]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    /// Decodes an array of `Sendable` values for a given key.
    ///
    /// - Parameters:
    ///   - type: The type of array to decode
    ///   - key: The coding key to decode from
    /// - Returns: An array of `Sendable` values
    /// - Throws: `DecodingError` if the value cannot be decoded
    public func decode(_ type: [any Sendable].Type, forKey key: K) throws -> [any Sendable] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }

    /// Decodes an array of `Sendable` values if present for a given key.
    ///
    /// - Parameters:
    ///   - type: The type of array to decode
    ///   - key: The coding key to decode from
    /// - Returns: An optional array of `Sendable` values, or `nil` if the key is not present or the value is null
    /// - Throws: `DecodingError` if the value cannot be decoded
    public func decodeIfPresent(_ type: [any Sendable].Type, forKey key: K) throws -> [any Sendable]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    /// Decodes a dictionary with string keys and `Sendable` values from the current container.
    ///
    /// This method iterates through all keys in the container and attempts to decode each value
    /// as a Bool, String, Int, Double, nested dictionary, or nested array.
    ///
    /// - Parameter type: The type of dictionary to decode
    /// - Returns: A dictionary with string keys and `Sendable` values containing all successfully decoded values
    /// - Throws: `DecodingError` if the container cannot be processed
    public func decode(_ type: [String: any Sendable].Type) throws -> [String: any Sendable] {
        var dictionary = [String: any Sendable]()
        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode(Dictionary<String, any Sendable>.self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode(Array<any Sendable>.self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        return dictionary
    }
}

/// Extensions for `UnkeyedDecodingContainer` to support decoding of dynamic arrays and dictionaries
/// with `Sendable` values from unkeyed JSON containers.
extension UnkeyedDecodingContainer {
    
    /// Decodes an array of `Sendable` values from the current container.
    ///
    /// This method iterates through all elements in the unkeyed container and attempts to decode each
    /// as a Bool, Double, String, nested dictionary, or nested array. Null values are skipped.
    ///
    /// - Parameter type: The type of array to decode
    /// - Returns: An array of `Sendable` values containing all successfully decoded elements
    /// - Throws: `DecodingError` if the container cannot be processed
    public mutating func decode(_ type: [any Sendable].Type) throws -> [any Sendable] {
        var array: [any Sendable] = []
        while isAtEnd == false {
            // See if the current value in the JSON array is `null` first and prevent infite recursion with nested arrays.
            if try decodeNil() {
                continue
            } else if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode(Dictionary<String, any Sendable>.self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode(Array<any Sendable>.self) {
                array.append(nestedArray)
            }
        }
        return array
    }

    /// Decodes a dictionary with string keys and `Sendable` values from a nested container.
    ///
    /// - Parameter type: The type of dictionary to decode
    /// - Returns: A dictionary with string keys and `Sendable` values
    /// - Throws: `DecodingError` if the nested container cannot be decoded
    public mutating func decode(_ type: [String: any Sendable].Type) throws -> [String: any Sendable] {
        let nestedContainer = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try nestedContainer.decode(type)
    }
}

//MARK:- Encoding Extensions

/// Extensions for `KeyedEncodingContainer` to support encoding of dynamic dictionaries and arrays
/// with `Sendable` values, enabling flexible JSON serialization.
extension KeyedEncodingContainer {
    
    /// Encodes a dictionary with string keys and `Sendable` values if present and non-empty.
    ///
    /// This method creates a nested container and encodes each value based on its runtime type,
    /// supporting Int, String, Double, Float, Bool, arrays, and nested dictionaries.
    ///
    /// - Parameters:
    ///   - value: The optional dictionary to encode
    ///   - key: The coding key to encode to
    /// - Throws: `EncodingError` if any value cannot be encoded
    public mutating func encodeIfPresent(_ value: [String: any Sendable]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard let safeValue = value, !safeValue.isEmpty else {
            return
        }
        var container = self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        for item in safeValue {
            if let val = item.value as? Int {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? String {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Double {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Float {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Bool {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? [any Sendable] {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? [String: any Sendable] {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            }
        }
    }
    
    /// Encodes an array of `Sendable` values if present.
    ///
    /// This method attempts to encode the array as a homogeneous collection based on its runtime type.
    /// If the array is heterogeneous or contains dictionaries, it creates a nested unkeyed container
    /// to encode each element individually.
    ///
    /// - Parameters:
    ///   - value: The optional array to encode
    ///   - key: The coding key to encode to
    /// - Throws: `EncodingError` if the array cannot be encoded
    public mutating func encodeIfPresent(_ value: [any Sendable]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard let safeValue = value else {
            return
        }
        if let val = safeValue as? [Int] {
            try self.encodeIfPresent(val, forKey: key)
        } else if let val = safeValue as? [String] {
            try self.encodeIfPresent(val, forKey: key)
        } else if let val = safeValue as? [Double] {
            try self.encodeIfPresent(val, forKey: key)
        } else if let val = safeValue as? [Float] {
            try self.encodeIfPresent(val, forKey: key)
        } else if let val = safeValue as? [Bool] {
            try self.encodeIfPresent(val, forKey: key)
        } else if let val = value as? [[String: any Sendable]] {
            var container = self.nestedUnkeyedContainer(forKey: key)
            try container.encode(contentsOf: val)
        }
    }
}

/// Extensions for `UnkeyedEncodingContainer` to support encoding of arrays of dictionaries
/// with `Sendable` values into unkeyed JSON containers.
extension UnkeyedEncodingContainer {
    
    /// Encodes an array of dictionaries with string keys and `Sendable` values.
    ///
    /// - Parameter sequence: The array of dictionaries to encode
    /// - Throws: `EncodingError` if any dictionary cannot be encoded
    public mutating func encode(contentsOf sequence: [[String: any Sendable]]) throws {
        for dict in sequence {
            try self.encodeIfPresent(dict)
        }
    }
    
    /// Encodes a dictionary with string keys and `Sendable` values into a nested container.
    ///
    /// This method creates a nested keyed container and encodes each value based on its runtime type,
    /// supporting Int, String, Double, Float, Bool, arrays, and nested dictionaries.
    ///
    /// - Parameter value: The dictionary to encode
    /// - Throws: `EncodingError` if any value cannot be encoded
    public mutating func encodeIfPresent(_ value: [String: any Sendable]) throws {
        var container = self.nestedContainer(keyedBy: JSONCodingKeys.self)
        for item in value {
            if let val = item.value as? Int {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? String {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Double {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Float {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? Bool {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? [any Sendable] {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            } else if let val = item.value as? [String: any Sendable] {
                try container.encodeIfPresent(val, forKey: JSONCodingKeys(stringValue: item.key)!)
            }
        }
    }
}

//MARK:- Extra extensions for managing data easily

/// Extensions to simplify conversion between `Decodable` types and dictionaries.
extension Decodable {
    
    /// Creates an instance of the conforming type from a dictionary with string keys and `Sendable` values.
    ///
    /// This convenience initializer converts the dictionary to JSON data and then decodes it
    /// using the type's `Decodable` implementation.
    ///
    /// - Parameter dictionary: A dictionary with string keys and `Sendable` values to decode from
    /// - Returns: An instance of the conforming type, or `nil` if decoding fails
    public init?(dictionary: [String: any Sendable]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            if let decodedData = Utility.decode(Self.self, from: data) {
                self = decodedData
            } else {
                return nil
            }
        } catch _ {
            return nil
        }
    }
}

/// Extensions to simplify conversion from `Encodable` types to dictionaries and JSON strings.
extension Encodable {
    
    /// Converts the conforming type to a dictionary with string keys and `Sendable` values.
    ///
    /// This computed property encodes the instance to JSON data and then converts it to a dictionary.
    ///
    /// - Returns: An optional dictionary representation of the instance, or `nil` if encoding fails
    public var dictionary: [String: any Sendable]? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: any Sendable] }
    }
    
    /// Converts the conforming type to a pretty-printed JSON string.
    ///
    /// This computed property first converts the instance to a dictionary, then formats it as
    /// an indented JSON string for readability.
    ///
    /// - Returns: A pretty-printed JSON string representation, or "{}" if conversion fails
    public var prettyJSON: String {
        dictionary?.prettyJSON ?? "{}"
    }
}

/// Extensions to simplify conversion of dictionaries to formatted JSON strings.
extension Dictionary {
    
    /// Converts the dictionary to a pretty-printed JSON string.
    ///
    /// This computed property serializes the dictionary to JSON with indentation for improved readability.
    ///
    /// - Returns: A pretty-printed JSON string representation, or "{}" if serialization fails
    public var prettyJSON: String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted])
            guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
                print("Can't create string with data.")
                return "{}"
            }
            return jsonString
        } catch let parseError {
            print("json serialization error: \(parseError)")
            return "{}"
        }
    }
}

/// A utility class providing helper methods for JSON decoding with detailed error reporting.
public class Utility {
    
    /// Decodes a `Decodable` type from JSON data with comprehensive error logging.
    ///
    /// This method attempts to decode the provided data and logs detailed error information
    /// if decoding fails, including:
    /// - Data corruption contexts
    /// - Missing keys with their coding paths
    /// - Value not found errors with types and paths
    /// - Type mismatch errors with expected types and paths
    ///
    /// - Parameters:
    ///   - decodable: The type to decode to
    ///   - data: The JSON data to decode from
    /// - Returns: An instance of the decoded type, or `nil` if decoding fails
    public static func decode<T>(_ decodable: T.Type, from data: Data) -> T? where T: Decodable {
        var decodedData: T?
        do {
            decodedData = try JSONDecoder().decode(T.self, from: data)
        } catch DecodingError.dataCorrupted(let context) {
            print(context)
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch DecodingError.valueNotFound(let value, let context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch DecodingError.typeMismatch(let type, let context) {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch {
            print("error: ", error)
        }
        return decodedData
    }
}
