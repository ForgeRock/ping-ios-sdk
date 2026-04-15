// 
//  CommonsTests.swift
//  CommonsTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingCommons

final class CommonsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Int8 Extension Tests
    
    func testConvertInt8ArrToStr_WithCommaSeparator() {
        let arr: [Int8] = [1, 2, 3, 4, 5]
        let result = Int8.convertInt8ArrToStr(arr, separator: ",")
        XCTAssertEqual(result, "1,2,3,4,5")
    }
    
    func testConvertInt8ArrToStr_WithSpaceSeparator() {
        let arr: [Int8] = [10, 20, 30]
        let result = Int8.convertInt8ArrToStr(arr, separator: " ")
        XCTAssertEqual(result, "10 20 30")
    }
    
    func testConvertInt8ArrToStr_WithEmptySeparator() {
        let arr: [Int8] = [1, 2, 3]
        let result = Int8.convertInt8ArrToStr(arr, separator: "")
        XCTAssertEqual(result, "123")
    }
    
    func testConvertInt8ArrToStr_WithEmptyArray() {
        let arr: [Int8] = []
        let result = Int8.convertInt8ArrToStr(arr, separator: ",")
        XCTAssertEqual(result, "")
    }
    
    func testConvertInt8ArrToStr_WithSingleElement() {
        let arr: [Int8] = [42]
        let result = Int8.convertInt8ArrToStr(arr, separator: ",")
        XCTAssertEqual(result, "42")
    }
    
    func testConvertInt8ArrToStr_WithNegativeValues() {
        let arr: [Int8] = [-128, 0, 127]
        let result = Int8.convertInt8ArrToStr(arr, separator: "-")
        XCTAssertEqual(result, "-128-0-127")
    }
}
