// 
//  CodableExtensions.swift
//  DeviceClient
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

//MARK:- Decoding Extensions
extension KeyedDecodingContainer {
    func decode(_ type: [String: any Sendable].Type, forKey key: K) throws -> [String: any Sendable] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    func decode(_ type: [[String: any Sendable]].Type, forKey key: K) throws -> [[String: any Sendable]] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        if let decodedData = try container.decode([any Sendable].self) as? [[String: any Sendable]] {
            return decodedData
        } else {
            return []
        }
    }

    func decodeIfPresent(_ type: [String: any Sendable].Type, forKey key: K) throws -> [String: any Sendable]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: [any Sendable].Type, forKey key: K) throws -> [any Sendable] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }

    func decodeIfPresent(_ type: [any Sendable].Type, forKey key: K) throws -> [any Sendable]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: [String: any Sendable].Type) throws -> [String: any Sendable] {
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

extension UnkeyedDecodingContainer {
    mutating func decode(_ type: [any Sendable].Type) throws -> [any Sendable] {
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

    mutating func decode(_ type: [String: any Sendable].Type) throws -> [String: any Sendable] {
        let nestedContainer = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try nestedContainer.decode(type)
    }
}

//MARK:- Encoding Extensions
extension KeyedEncodingContainer {
    mutating func encodeIfPresent(_ value: [String: any Sendable]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
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
    
    mutating func encodeIfPresent(_ value: [any Sendable]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
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

extension UnkeyedEncodingContainer {
    mutating func encode(contentsOf sequence: [[String: any Sendable]]) throws {
        for dict in sequence {
            try self.encodeIfPresent(dict)
        }
    }
    
    mutating func encodeIfPresent(_ value: [String: any Sendable]) throws {
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
extension Decodable {
    init?(dictionary: [String: any Sendable]) {
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

extension Encodable {
    var dictionary: [String: any Sendable]? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: any Sendable] }
    }
    
    var prettyJSON: String {
        dictionary?.prettyJSON ?? "{}"
    }
}

extension Dictionary {
    var prettyJSON: String {
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

class Utility {
    static func decode<T>(_ decodable: T.Type, from data: Data) -> T? where T: Decodable {
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
