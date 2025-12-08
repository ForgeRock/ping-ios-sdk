// 
//  AnyValueTests.swift
//  Commons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

// MARK: - AnyValue Tests

func testAnyValueWithString() throws {
    let value = AnyValue("test string")
    XCTAssertEqual(value.value as? String, "test string", "String value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    XCTAssertEqual(decoded.value as? String, "test string", "Decoded string should match")
}

func testAnyValueWithInt() throws {
    let value = AnyValue(42)
    XCTAssertEqual(value.value as? Int, 42, "Int value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    XCTAssertEqual(decoded.value as? Int, 42, "Decoded int should match")
}

func testAnyValueWithDouble() throws {
    let value = AnyValue(3.14159)
    XCTAssertEqual(value.value as? Double, 3.14159, "Double value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    XCTAssertEqual(decoded.value as? Double, 3.14159, "Decoded double should match")
}

func testAnyValueWithBool() throws {
    let trueValue = AnyValue(true)
    let falseValue = AnyValue(false)
    
    XCTAssertEqual(trueValue.value as? Bool, true, "Bool true value should be preserved")
    XCTAssertEqual(falseValue.value as? Bool, false, "Bool false value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let trueData = try encoder.encode(trueValue)
    let falseData = try encoder.encode(falseValue)
    
    let decoder = JSONDecoder()
    let decodedTrue = try decoder.decode(AnyValue.self, from: trueData)
    let decodedFalse = try decoder.decode(AnyValue.self, from: falseData)
    
    XCTAssertEqual(decodedTrue.value as? Bool, true, "Decoded true should match")
    XCTAssertEqual(decodedFalse.value as? Bool, false, "Decoded false should match")
}

func testAnyValueWithArray() throws {
    let arrayValue = [1, 2, 3]
    let value = AnyValue(arrayValue)
    
    let retrievedArray = value.value as? [Int]
    XCTAssertEqual(retrievedArray, arrayValue, "Array value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    let decodedArray = decoded.value as? [Int]
    XCTAssertEqual(decodedArray, arrayValue, "Decoded array should match")
}

func testAnyValueWithDictionary() throws {
    let dictValue = ["key1": "value1", "key2": "value2"]
    let value = AnyValue(dictValue)
    
    let retrievedDict = value.value as? [String: String]
    XCTAssertEqual(retrievedDict, dictValue, "Dictionary value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    let decodedDict = decoded.value as? [String: String]
    XCTAssertEqual(decodedDict, dictValue, "Decoded dictionary should match")
}

func testAnyValueWithNSNull() throws {
    let value = AnyValue(NSNull())
    XCTAssertTrue(value.value is NSNull, "NSNull value should be preserved")
    
    // Test encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AnyValue.self, from: data)
    
    XCTAssertTrue(decoded.value is NSNull, "Decoded NSNull should match")
}
