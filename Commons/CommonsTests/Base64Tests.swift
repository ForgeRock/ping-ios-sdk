//
//  UriParserTests.swift
//  PingCommonsTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

final class Base64Tests: XCTestCase {
    
    func testIsBase64Encoded_Valid() {
        XCTAssertTrue(Base64.isBase64Encoded("SGVsbG8gV29ybGQ=")) // "Hello World"
        XCTAssertTrue(Base64.isBase64Encoded("SGVsbG8gV29ybGQ")) // Without padding
        XCTAssertTrue(Base64.isBase64Encoded("SGVsbG9fV29ybGQ")) // URL-safe
        XCTAssertTrue(Base64.isBase64Encoded("SGVsbG8tV29ybGQ")) // URL-safe with dash
    }
    
    func testIsBase64Encoded_Invalid() {
        XCTAssertFalse(Base64.isBase64Encoded("Invalid Base64!@#$"))
        XCTAssertFalse(Base64.isBase64Encoded(" "))
        XCTAssertFalse(Base64.isBase64Encoded("Hello World"))
    }
    
    func testDecodeBase64_Valid() throws {
        let result = try Base64.decodeBase64("SGVsbG8gV29ybGQ=")
        XCTAssertEqual(result, "Hello World")
    }
    
    func testDecodeBase64_Invalid() {
        XCTAssertThrowsError(try Base64.decodeBase64("Invalid Base64!@#$")) { error in
            XCTAssertTrue(error is Base64Error)
        }
    }
    
    func testDecodeBase64Url_Valid() throws {
        let result = try Base64.decodeBase64Url("SGVsbG8gV29ybGQ") // Without padding
        XCTAssertEqual(result, "Hello World")
        
        let urlSafeResult = try Base64.decodeBase64Url("SGVsbG8tV29ybGQ") // URL-safe
        XCTAssertEqual(urlSafeResult, "Hello-World")
    }
    
    func testDecodeBase64Url_Invalid() {
        XCTAssertThrowsError(try Base64.decodeBase64Url("Invalid Base64!@#$")) { error in
            XCTAssertTrue(error is Base64Error)
        }
    }
    
    func testEncodeBase64_Valid() {
        let result = Base64.encodeBase64("Hello World")
        XCTAssertEqual(result, "SGVsbG8gV29ybGQ")
        
        let urlSafeResult = Base64.encodeBase64("Hello-World")
        XCTAssertEqual(urlSafeResult, "SGVsbG8tV29ybGQ")
    }
    
    func testRecodeBase64NoWrapUrlSafeValueToNoWrap() throws {
        let urlSafeValue = "SGVsbG8tV29ybGQ" // URL-safe "Hello-World"
        let result = try Base64.recodeBase64NoWrapUrlSafeValueToNoWrap(urlSafeValue)
        XCTAssertEqual(result, "SGVsbG8tV29ybGQ=") // Standard Base64 with padding
    }
    
    func testRecodeBase64NoWrapValueToUrlSafeNoWrap() throws {
        let standardValue = "SGVsbG8tV29ybGQ=" // Standard Base64 with padding
        let result = try Base64.recodeBase64NoWrapValueToUrlSafeNoWrap(standardValue)
        XCTAssertEqual(result, "SGVsbG8tV29ybGQ") // URL-safe without padding
    }
    
    func testBase64_EmptyString() throws {
        let result = Base64.encodeBase64("")
        XCTAssertEqual(result, "")
        
        let decoded = try Base64.decodeBase64("")
        XCTAssertEqual(decoded, "")
    }
    
    func testBase64_UnicodeCharacters() throws {
        let unicodeText = "Hello 世界 🌍"
        let encoded = Base64.encodeBase64(unicodeText)
        let decoded = try Base64.decodeBase64Url(encoded)
        XCTAssertEqual(decoded, unicodeText)
    }
    
}
