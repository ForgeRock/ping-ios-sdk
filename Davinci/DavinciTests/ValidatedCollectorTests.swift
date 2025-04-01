// 
//  ValidatedCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

class ValidatedCollectorTest: XCTestCase {
    
    func testValidatesSuccessfullyWhenNoErrors() {
        let input: [String: Any] = [
            "validation": [
                "regex": ".*",
                "errorMessage": "Invalid format"
            ]
        ]
        
        let collector = ValidatedCollector(with: input)
        collector.value = "validValue"
        
        XCTAssertEqual([], collector.validate())
    }
    
    func testAddsRequiredErrorWhenValueIsEmpty() {
        let input: [String: Any] = [
            "required": true,
            "validation": [
                "regex": ".*",
                "errorMessage": "Invalid format"
            ]
        ]
        
        let collector = ValidatedCollector(with: input)
        collector.value = ""
        
        XCTAssertEqual([.required], collector.validate())
    }
    
    func testAddsRegexErrorWhenValueDoesNotMatch() {
        let input: [String: Any] = [
            "validation": [
                "regex": "^\\d+$",
                "errorMessage": "Must be digits"
            ]
        ]
        
        let collector = ValidatedCollector(with: input)
        collector.value = "invalidValue"
        
        XCTAssertEqual([.regexError(message: "Must be digits")], collector.validate())
    }
    
    func testAddsBothErrorsWhenValueIsEmptyAndDoesNotMatchRegex() {
        let input: [String: Any] = [
            "required": true,
            "validation": [
                "regex": "^\\d+$",
                "errorMessage": "Must be digits"
            ]
        ]
        
        let collector = ValidatedCollector(with: input)
        collector.value = ""
        
        XCTAssertEqual([.required, .regexError(message: "Must be digits")], collector.validate())
    }
}
