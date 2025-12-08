//
//  CodableExtensionsTests.swift
//  CommonsTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

/// Tests for Codable Extensions
final class CodableExtensionsTests: XCTestCase {
    
    // MARK: - Dictionary Decoding Tests
    
    func testDecodeDictionaryWithStrings() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = [
            "data": [
                "name": "John",
                "city": "New York"
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertEqual(model.data["name"] as? String, "John")
        XCTAssertEqual(model.data["city"] as? String, "New York")
    }
    
    func testDecodeDictionaryWithNumbers() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = [
            "data": [
                "age": 30,
                "height": 5.9,
                "isActive": true
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertEqual(model.data["age"] as? Int, 30)
        XCTAssertEqual(model.data["height"] as? Double, 5.9)
        XCTAssertEqual(model.data["isActive"] as? Bool, true)
    }
    
    func testDecodeDictionaryWithNestedDictionary() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = [
            "data": [
                "user": [
                    "name": "John",
                    "age": 30
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        let user = model.data["user"] as? [String: any Sendable]
        XCTAssertNotNil(user)
        XCTAssertEqual(user?["name"] as? String, "John")
        XCTAssertEqual(user?["age"] as? Int, 30)
    }
    
    func testDecodeDictionaryWithArray() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = [
            "data": [
                "tags": ["swift", "ios", "mobile"]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        let tags = model.data["tags"] as? [any Sendable]
        XCTAssertNotNil(tags)
        XCTAssertEqual(tags?.count, 3)
    }
    
    func testDecodeArrayOfDictionaries() throws {
        struct TestModel: Decodable {
            let items: [[String: any Sendable]]
            
            enum CodingKeys: String, CodingKey {
                case items
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                items = try container.decode([[String: any Sendable]].self, forKey: .items)
            }
        }
        
        let json: [String: Any] = [
            "items": [
                ["name": "Item 1", "price": 10],
                ["name": "Item 2", "price": 20]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.items[0]["name"] as? String, "Item 1")
        XCTAssertEqual(model.items[1]["price"] as? Int, 20)
    }
    
    func testDecodeIfPresentDictionary() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]?
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decodeIfPresent([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = [:]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertNil(model.data)
    }
    
    // MARK: - Dictionary Encoding Tests
    
    func testEncodeDictionaryWithStrings() throws {
        struct TestModel: Encodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let model = TestModel(data: [
            "name": "John",
            "city": "New York"
        ])
        
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        let data = json?["data"] as? [String: Any]
        XCTAssertEqual(data?["name"] as? String, "John")
        XCTAssertEqual(data?["city"] as? String, "New York")
    }
    
    func testEncodeDictionaryWithNumbers() throws {
        struct TestModel: Encodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let model = TestModel(data: [
            "age": 30,
            "height": 5.9,
            "score": Float(95.5),
            "isActive": true
        ])
        
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        let data = json?["data"] as? [String: Any]
        XCTAssertEqual(data?["age"] as? Int, 30)
        XCTAssertNotNil(data?["height"])
        XCTAssertEqual(data?["isActive"] as? Bool, true)
    }
    
    func testEncodeDictionaryWithNestedDictionary() throws {
        struct TestModel: Encodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let nestedData: [String: any Sendable] = [
            "name": "John",
            "age": 30
        ]
        
        let model = TestModel(data: [
            "user": nestedData
        ])
        
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        let data = json?["data"] as? [String: Any]
        let user = data?["user"] as? [String: Any]
        XCTAssertEqual(user?["name"] as? String, "John")
    }
    
    func testEncodeArrayOfDictionaries() throws {
        struct TestModel: Encodable {
            let items: [any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case items
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(items, forKey: .items)
            }
        }
        
        let dict1: [String: any Sendable] = ["name": "Item 1", "price": 10]
        let dict2: [String: any Sendable] = ["name": "Item 2", "price": 20]
        
        let model = TestModel(items: [dict1, dict2])
        
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        let items = json?["items"] as? [[String: Any]]
        XCTAssertEqual(items?.count, 2)
    }
    
    func testEncodeIfPresentEmptyDictionary() throws {
        struct TestModel: Encodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let model = TestModel(data: [:])
        
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Empty dictionary should not be encoded
        XCTAssertNil(json?["data"])
    }
    
    // MARK: - Round Trip Tests
    
    func testRoundTripSimpleDictionary() throws {
        struct TestModel: Codable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(data: [String: any Sendable]) {
                self.data = data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let original = TestModel(data: [
            "name": "Test",
            "value": 42,
            "active": true
        ])
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestModel.self, from: encoded)
        
        XCTAssertEqual(decoded.data["name"] as? String, "Test")
        XCTAssertEqual(decoded.data["value"] as? Int, 42)
        XCTAssertEqual(decoded.data["active"] as? Bool, true)
    }
    
    func testRoundTripComplexDictionary() throws {
        struct TestModel: Codable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(data: [String: any Sendable]) {
                self.data = data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let nestedDict: [String: any Sendable] = ["nested": "value"]
        let original = TestModel(data: [
            "string": "test",
            "number": 123,
            "double": 45.67,
            "bool": false,
            "nested": nestedDict
        ])
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestModel.self, from: encoded)
        
        XCTAssertEqual(decoded.data["string"] as? String, "test")
        XCTAssertEqual(decoded.data["number"] as? Int, 123)
        XCTAssertEqual(decoded.data["bool"] as? Bool, false)
        XCTAssertNotNil(decoded.data["nested"])
    }
    
    // MARK: - Decodable Extension Tests
    
    func testDecodableInitWithDictionary() {
        struct Person: Decodable {
            let name: String
            let age: Int
        }
        
        let dictionary: [String: any Sendable] = [
            "name": "John Doe",
            "age": 30
        ]
        
        let person = Person(dictionary: dictionary)
        
        XCTAssertNotNil(person)
        XCTAssertEqual(person?.name, "John Doe")
        XCTAssertEqual(person?.age, 30)
    }
    
    func testDecodableInitWithInvalidDictionary() {
        struct Person: Decodable {
            let name: String
            let age: Int
        }
        
        let dictionary: [String: any Sendable] = [
            "name": "John Doe"
            // Missing "age"
        ]
        
        let person = Person(dictionary: dictionary)
        
        XCTAssertNil(person)
    }
    
    // MARK: - Encodable Extension Tests
    
    func testEncodableDictionaryProperty() {
        struct Person: Encodable {
            let name: String
            let age: Int
        }
        
        let person = Person(name: "Jane Doe", age: 25)
        let dictionary = person.dictionary
        
        XCTAssertNotNil(dictionary)
        XCTAssertEqual(dictionary?["name"] as? String, "Jane Doe")
        XCTAssertEqual(dictionary?["age"] as? Int, 25)
    }
    
    func testEncodablePrettyJSONProperty() {
        struct Person: Encodable {
            let name: String
            let age: Int
        }
        
        let person = Person(name: "Bob", age: 40)
        let prettyJSON = person.prettyJSON
        
        XCTAssertTrue(prettyJSON.contains("name"))
        XCTAssertTrue(prettyJSON.contains("Bob"))
        XCTAssertTrue(prettyJSON.contains("age"))
        XCTAssertTrue(prettyJSON.contains("40"))
    }
    
    func testEncodableFailureReturnEmptyJSON() {
        // Test object that can't be encoded (contains closure)
        struct InvalidObject: Encodable {
            let name: String
            
            func encode(to encoder: Encoder) throws {
                throw NSError(domain: "Test", code: 0)
            }
        }
        
        let obj = InvalidObject(name: "test")
        let prettyJSON = obj.prettyJSON
        
        XCTAssertEqual(prettyJSON, "{}")
    }
    
    // MARK: - Dictionary Extension Tests
    
    func testDictionaryPrettyJSON() {
        let dictionary: [String: Any] = [
            "name": "Test",
            "value": 123,
            "nested": [
                "key": "value"
            ]
        ]
        
        let prettyJSON = dictionary.prettyJSON
        
        XCTAssertTrue(prettyJSON.contains("name"))
        XCTAssertTrue(prettyJSON.contains("Test"))
        XCTAssertTrue(prettyJSON.contains("nested"))
        XCTAssertFalse(prettyJSON.isEmpty)
    }
    
    func testDictionaryPrettyJSONWithIndentation() {
        let dictionary: [String: Any] = [
            "level1": [
                "level2": "value"
            ]
        ]
        
        let prettyJSON = dictionary.prettyJSON
        
        // Pretty printed JSON should have indentation/newlines
        XCTAssertTrue(prettyJSON.contains("\n"))
    }
    
    // MARK: - Utility Class Tests
    
    func testUtilityDecodeSuccess() {
        struct TestModel: Decodable {
            let name: String
            let value: Int
        }
        
        let json: [String: Any] = [
            "name": "Test",
            "value": 42
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoded = Utility.decode(TestModel.self, from: data)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.name, "Test")
        XCTAssertEqual(decoded?.value, 42)
    }
    
    func testUtilityDecodeFailure() {
        struct TestModel: Decodable {
            let name: String
            let value: Int
        }
        
        let json: [String: Any] = [
            "name": "Test"
            // Missing required "value"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoded = Utility.decode(TestModel.self, from: data)
        
        XCTAssertNil(decoded)
    }
    
    func testUtilityDecodeInvalidJSON() {
        struct TestModel: Decodable {
            let name: String
        }
        
        let invalidData = "not json".data(using: .utf8)!
        let decoded = Utility.decode(TestModel.self, from: invalidData)
        
        XCTAssertNil(decoded)
    }
    
    // MARK: - Edge Cases
    
    func testDecodeEmptyDictionary() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any] = ["data": [:]]
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertTrue(model.data.isEmpty)
    }
    
    func testDecodeNullValue() throws {
        struct TestModel: Decodable {
            let data: [String: any Sendable]?
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decodeIfPresent([String: any Sendable].self, forKey: .data)
            }
        }
        
        let json: [String: Any?] = ["data": nil]
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        XCTAssertNil(model.data)
    }
    
    func testDecodeArrayWithNullValues() throws {
        struct TestModel: Decodable {
            let items: [any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case items
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                items = try container.decode([any Sendable].self, forKey: .items)
            }
        }
        
        let json: [String: Any] = [
            "items": [1, NSNull(), "test", NSNull(), true]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let model = try JSONDecoder().decode(TestModel.self, from: jsonData)
        
        // Nulls should be skipped
        XCTAssertEqual(model.items.count, 3)
    }
    
    func testEncodeNilDictionary() throws {
        struct TestModel: Encodable {
            let data: [String: any Sendable]?
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let model = TestModel(data: nil)
        let jsonData = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        XCTAssertNil(json?["data"])
    }
    
    // MARK: - Complex Nested Structure Tests
    
    func testComplexNestedStructure() throws {
        struct TestModel: Codable {
            let data: [String: any Sendable]
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            init(data: [String: any Sendable]) {
                self.data = data
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                data = try container.decode([String: any Sendable].self, forKey: .data)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }
        
        let level3: [String: any Sendable] = ["deepValue": "found"]
        let level2: [String: any Sendable] = ["level3": level3]
        let level1: [String: any Sendable] = ["level2": level2]
        
        let original = TestModel(data: [
            "level1": level1,
            "topLevel": "value"
        ])
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestModel.self, from: encoded)
        
        XCTAssertNotNil(decoded.data["level1"])
        XCTAssertEqual(decoded.data["topLevel"] as? String, "value")
    }
}
