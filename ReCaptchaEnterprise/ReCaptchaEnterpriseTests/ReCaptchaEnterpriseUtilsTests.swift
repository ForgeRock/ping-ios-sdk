// 
//  ReCaptchaEnterpriseUtilsTests.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingReCaptchaEnterprise

class ReCaptchaEnterpriseUtilsTests: XCTestCase {
    
    func testJSONStringifyWithValidDictionary() {
        // Given: Valid dictionary
        let testData: [String: Any] = [
            "name": "John Doe",
            "age": 30,
            "active": true
        ]
        
        // When: Converting to JSON string
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: testData)
        
        // Then: Should produce valid JSON string
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("name"))
        XCTAssertTrue(jsonString.contains("John Doe"))
        XCTAssertTrue(jsonString.contains("age"))
        XCTAssertTrue(jsonString.contains("30"))
    }
    
    func testJSONStringifyWithValidArray() {
        // Given: Valid array
        let testData: [Any] = ["item1", "item2", 123, true]
        
        // When: Converting to JSON string
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: testData)
        
        // Then: Should produce valid JSON string
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("item1"))
        XCTAssertTrue(jsonString.contains("item2"))
    }
    
    func testJSONStringifyWithNestedStructure() {
        // Given: Nested structure
        let testData: [String: Any] = [
            "user": [
                "name": "Jane",
                "roles": ["admin", "user"]
            ],
            "settings": [
                "theme": "dark",
                "notifications": true
            ]
        ]
        
        // When: Converting to JSON string
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: testData)
        
        // Then: Should handle nested structure
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("user"))
        XCTAssertTrue(jsonString.contains("Jane"))
        XCTAssertTrue(jsonString.contains("admin"))
        XCTAssertTrue(jsonString.contains("theme"))
    }
    
    func testJSONStringifyWithPrettyPrint() {
        // Given: Dictionary and pretty print enabled
        let testData: [String: Any] = [
            "key1": "value1",
            "key2": "value2"
        ]
        
        // When: Converting with pretty print
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(
            value: testData,
            prettyPrinted: true
        )
        
        // Then: Should contain newlines and indentation
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("\n"))
    }
    
    func testJSONStringifyWithInvalidObject() {
        // Given: Invalid JSON object (custom class instance)
        class InvalidObject {
            var property = "value"
        }
        let invalidObject = InvalidObject()
        
        // When: Attempting to convert invalid object
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: invalidObject)
        
        // Then: Should return empty string
        XCTAssertEqual(jsonString, "")
    }
    
    func testJSONStringifyWithEmptyDictionary() {
        // Given: Empty dictionary
        let emptyDict: [String: Any] = [:]
        
        // When: Converting empty dictionary
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: emptyDict)
        
        // Then: Should produce valid empty JSON object
        XCTAssertEqual(jsonString, "{}")
    }
    
    func testJSONStringifyWithEmptyArray() {
        // Given: Empty array
        let emptyArray: [Any] = []
        
        // When: Converting empty array
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: emptyArray)
        
        // Then: Should produce valid empty JSON array
        XCTAssertEqual(jsonString, "[]")
    }
    
    func testJSONStringifyPreservesDataTypes() {
        // Given: Dictionary with various types
        let testData: [String: Any] = [
            "string": "text",
            "integer": 42,
            "double": 3.14,
            "boolean": true,
            "null": NSNull()
        ]
        
        // When: Converting to JSON
        let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: testData)
        
        // Then: Should preserve all data types
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("\"string\""))
        XCTAssertTrue(jsonString.contains("42"))
        XCTAssertTrue(jsonString.contains("3.14"))
        XCTAssertTrue(jsonString.contains("true"))
        XCTAssertTrue(jsonString.contains("null"))
    }
}
