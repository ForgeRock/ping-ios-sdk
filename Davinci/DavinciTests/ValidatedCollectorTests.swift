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

    // MARK: - Full-match evaluation

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

    func testUnanchoredPatternRejectsPartialMatch() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "[0-9]+", value: "abc1"))
    }

    func testUnanchoredPatternAcceptsFullMatch() {
        XCTAssertEqual([], validate(regex: "[0-9]+", value: "1234"))
    }

    func testUnanchoredPatternRejectsTrailingJunk() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "[0-9]+", value: "12ab"))
    }

    func testUnanchoredPatternRejectsLeadingJunk() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "[0-9]+", value: "ab12"))
    }

    func testAnchoredPatternBehaviorUnchanged() {
        XCTAssertEqual([], validate(regex: "^[0-9]+$", value: "1234"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "abc1"))
    }

    func testAlternationBacktracksToFullMatch() {
        XCTAssertEqual([], validate(regex: "a|ab", value: "ab"))
    }

    func testAnchoredPatternRejectsTrailingNewline() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "123\n"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^[0-9]+$", value: "123\r\n"))
    }

    func testInlineFlagsApplyToFullMatch() {
        XCTAssertEqual([], validate(regex: "(?i)abc", value: "ABC"))
    }

    func testInvalidPatternIsIgnored() {
        XCTAssertEqual([], validate(regex: "a)|(b", value: "x"))
        XCTAssertEqual([], validate(regex: "a)|(b", value: "anything"))
    }

    func testPublicRegexKeepsOriginalPattern() {
        let collector = ValidatedCollector(with: validationInput(regex: "[0-9]+"))
        XCTAssertEqual("[0-9]+", collector.validation?.regex?.pattern)
    }

    func testPatternThatCannotBeWrappedFallsBackToPartialMatch() {
        XCTAssertEqual([], validate(regex: "\\Qabc", value: "abc"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "\\Qabc", value: "zzz"))
        XCTAssertEqual([], validate(regex: "(?x)abc # comment", value: "xabcx"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "(?x)abc # comment", value: "1234"))
    }

    func testDotDoesNotSpanNewlineInFullMatch() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: ".*", value: "a\nb"))
    }

    func testTextCollectorRequiresFullMatch() {
        let collector = TextCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
        collector.value = "1234"
        XCTAssertEqual([], collector.validate())
    }

    func testPasswordCollectorRequiresFullMatch() {
        let collector = PasswordCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
        collector.value = "1234"
        XCTAssertEqual([], collector.validate())
    }

    func testSingleSelectCollectorRequiresFullMatch() {
        let collector = SingleSelectCollector(with: validationInput(regex: "[0-9]+"))
        collector.value = "abc1"
        XCTAssertEqual([.regexError(message: "Digits only")], collector.validate())
        collector.value = "1234"
        XCTAssertEqual([], collector.validate())
    }

    func testAnchoredTenantPatternsBehaveAsBefore() {
        let username = "^[a-zA-Z0-9]+$"
        XCTAssertEqual([], validate(regex: username, value: "user123"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: username, value: "user 123"))

        let email = "^[^@]+@[^@]+\\.[^@]+$"
        XCTAssertEqual([], validate(regex: email, value: "valid@email.com"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: email, value: "not an email"))
    }

    func testEmptyOptionalValueIsCheckedAgainstPattern() {
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "[0-9]+", value: ""))
        XCTAssertEqual([], validate(regex: "[0-9]*", value: ""))
    }

    func testEmptyPatternThroughPublicInitIsIgnored() {
        let validation = Validation(regexPattern: "", errorMessage: "ignored")
        XCTAssertNil(validation.regex)
        XCTAssertTrue(validation.matchesEntireValue("anything"))
    }

    func testNonBmpAndCombiningValuesMatchWholeValue() {
        XCTAssertEqual([], validate(regex: "^.$", value: "😀"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "^.$", value: "😀😀"))
        XCTAssertEqual([], validate(regex: ".+", value: "e\u{301}"))
    }

    func testWrapperKeepsBackreferenceNumbering() {
        XCTAssertEqual([], validate(regex: "(a)\\1", value: "aa"))
        XCTAssertEqual([.regexError(message: "Digits only")], validate(regex: "(a)\\1", value: "ab"))
    }

    func testMultilineValueMatchesWhenPatternSpansNewlines() {
        XCTAssertEqual([], validate(regex: "[\\s\\S]*", value: "a\nb"))
    }

    func testPasswordCollectorReportsRegexErrorBeforePolicyErrors() {
        var input = validationInput(regex: "[0-9]+")
        input["passwordPolicy"] = ["maxRepeatedCharacters": 2]
        let collector = PasswordCollector(with: input)
        collector.value = "aaabbb"
        XCTAssertEqual([.regexError(message: "Digits only"), .maxRepeat(max: 2)], collector.validate())
    }
}
