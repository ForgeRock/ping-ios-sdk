
//
//  FidoExtensionsTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido

class FidoExtensionsTests: XCTestCase {

    func testDataExtensions() {
        let data = "Hello World".data(using: .utf8)!
        XCTAssertEqual(data.bytesArray, [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100])
        
        let base64Url = data.base64urlEncodedString()
        XCTAssertEqual(base64Url, "SGVsbG8gV29ybGQ")
    }
    
    func testStringExtensions() {
        let string = "Hello World"
        XCTAssertEqual(string.toBase64(), "SGVsbG8gV29ybGQ=")
        
        let base64Url = string.base64urlEncodedString()
        XCTAssertEqual(base64Url, "SGVsbG8gV29ybGQ")
    }
    
    func testConvertInt8ArrToStr() {
        let arr: [Int8] = [72, 101, 108, 108, 111]
        XCTAssertEqual(convertInt8ArrToStr(arr), "72,101,108,108,111")
    }
    
    func testBase64ToBase64url() {
        let base64 = "SGVsbG8gV29ybGQ="
        XCTAssertEqual(base64ToBase64url(base64: base64), "SGVsbG8gV29ybGQ")
        
        let base64WithPlus = "Zm9v+g=="
        XCTAssertEqual(base64ToBase64url(base64: base64WithPlus), "Zm9v-g")
        
        let base64WithSlash = "Zm9v/g=="
        XCTAssertEqual(base64ToBase64url(base64: base64WithSlash), "Zm9v_g")
    }
}
