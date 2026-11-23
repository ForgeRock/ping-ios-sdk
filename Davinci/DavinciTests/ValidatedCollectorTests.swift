// 
//  ValidatedCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci
import PingDavinciPlugin

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

    // MARK: - Pattern matches anywhere in the value, as in PingOne Forms

    private func validationInput(regex: String, message: String = "Digits only") -> [String: Any] {
        return [
            "validation": [
                "regex": regex,
                "errorMessage": message
            ]
        ]
    }

    private func validate(regex: String, value: String) -> [ValidationError] {
        let collector = ValidatedCollector(with: validationInput(regex: regex))
        collector.value = value
        return collector.validate()
    }

    func testUnanchoredPatternMatchesAnywhereInValue() {
        XCTAssertEqual([], validate(regex: "[0-9]+", value: "1234"))
        XCTAssertEqual([], validate(regex: "[0-9]+", value: "abc1"))
        XCTAssertEqual([], validate(regex: "[0-9]+", value: "12ab"))
        XCTAssertEqual([], validate(regex: "[0-9]+", value: "ab12cd"))
    }

    func testUnanchoredPatternRejectsValueWithoutMatch() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "[0-9]+", value: "abc"))
    }

    func testAnchoredPatternRequiresEntireValue() {
        XCTAssertEqual([], validate(regex: "^[0-9]+$", value: "1234"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "abc1"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "12ab"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "ab12"))
    }

    func testAnchoredTenantPatternsRequireEntireValue() {
        let username = "^[a-zA-Z0-9]+$"
        XCTAssertEqual([], validate(regex: username, value: "user123"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: username, value: "user 123"))

        let email = "^[^@]+@[^@]+\\.[^@]+$"
        XCTAssertEqual([], validate(regex: email, value: "valid@email.com"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: email, value: "not an email"))
    }

    func testTextCollectorMatchesPatternAnywhereInValue() {
        let collector = TextCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([], collector.validate())
        collector.value = "abc"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
    }

    func testPasswordCollectorMatchesPatternAnywhereInValue() {
        let collector = PasswordCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([], collector.validate())
        collector.value = "abc"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
    }

    func testSingleSelectCollectorMatchesPatternAnywhereInValue() {
        let collector = SingleSelectCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([], collector.validate())
        collector.value = "abc"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
    }

    func testInvalidPatternIsIgnored() {
        XCTAssertNil(Validation(regexPattern: "a)|(b", errorMessage: "ignored").regex)
        XCTAssertEqual([], validate(regex: "a)|(b", value: "anything"))
    }

    func testEmptyPatternIsIgnored() {
        XCTAssertNil(Validation(regexPattern: "", errorMessage: "ignored").regex)
        XCTAssertEqual([], validate(regex: "", value: "anything"))
    }

    func testNonBmpValueIsMatchedOverItsFullUtf16Range() {
        XCTAssertEqual([], validate(regex: "^.$", value: "😀"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^.$", value: "😀😀"))
    }
}
