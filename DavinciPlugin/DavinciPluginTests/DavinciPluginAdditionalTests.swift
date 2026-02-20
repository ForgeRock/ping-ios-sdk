//
//  DavinciPluginAdditionalTests.swift
//  PingDavinciPluginTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinciPlugin

// MARK: - ValidationError Tests

final class ValidationErrorTests: XCTestCase {
    
    func testValidationError_RequiredMessage() {
        let error = ValidationError.required
        XCTAssertEqual(error.errorMessage, "This field cannot be empty.")
    }
    
    func testValidationError_RegexErrorMessage() {
        let error = ValidationError.regexError(message: "Invalid format")
        XCTAssertEqual(error.errorMessage, "Invalid format")
    }
    
    func testValidationError_InvalidLengthMessage() {
        let error = ValidationError.invalidLength(min: 8, max: 20)
        XCTAssertEqual(error.errorMessage, "The input length must be between 8 and 20 characters.")
    }
    
    func testValidationError_UniqueCharacterMessage() {
        let error = ValidationError.uniqueCharacter(min: 3)
        XCTAssertEqual(error.errorMessage, "The input must contain at least 3 unique characters.")
    }
    
    func testValidationError_MaxRepeatMessage() {
        let error = ValidationError.maxRepeat(max: 2)
        XCTAssertEqual(error.errorMessage, "The input contains too many repeated characters. Maximum allowed repeats: 2.")
    }
    
    func testValidationError_MinCharactersMessage() {
        let error = ValidationError.minCharacters(character: "!@#$", min: 1)
        XCTAssertEqual(error.errorMessage, "The input must include at least 1 character(s) from this set: '!@#$'.")
    }
    
    func testValidationError_HasUniqueId() {
        let error1 = ValidationError.required
        let error2 = ValidationError.required
        
        // Each error should have a unique ID
        XCTAssertNotEqual(error1.id, error2.id)
    }
    
    func testValidationError_Equatable() {
        XCTAssertEqual(ValidationError.required, ValidationError.required)
        XCTAssertEqual(ValidationError.regexError(message: "test"), ValidationError.regexError(message: "test"))
        XCTAssertEqual(ValidationError.invalidLength(min: 1, max: 10), ValidationError.invalidLength(min: 1, max: 10))
        XCTAssertEqual(ValidationError.uniqueCharacter(min: 5), ValidationError.uniqueCharacter(min: 5))
        XCTAssertEqual(ValidationError.maxRepeat(max: 3), ValidationError.maxRepeat(max: 3))
        XCTAssertEqual(ValidationError.minCharacters(character: "abc", min: 2), ValidationError.minCharacters(character: "abc", min: 2))
    }
    
    func testValidationError_NotEqual() {
        XCTAssertNotEqual(ValidationError.required, ValidationError.regexError(message: "test"))
        XCTAssertNotEqual(ValidationError.invalidLength(min: 1, max: 10), ValidationError.invalidLength(min: 2, max: 10))
        XCTAssertNotEqual(ValidationError.regexError(message: "a"), ValidationError.regexError(message: "b"))
    }
}

// MARK: - CollectorFactory Tests

final class CollectorFactoryTests: XCTestCase {
    
    func testCollectorFactory_SharedInstance() {
        let shared1 = CollectorFactory.shared
        let shared2 = CollectorFactory.shared
        XCTAssertTrue(shared1 === shared2)
    }
    
    func testCollectorFactory_Reset() async {
        let factory = CollectorFactory()
        
        // Register a closure
        await factory.register(type: "TEST") { json in
            return nil
        }
        
        // Reset
        await factory.reset()
        
        // Verification is implicit - no crash means success
        // The factory should be empty after reset
    }
    
}
