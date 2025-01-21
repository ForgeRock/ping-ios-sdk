// 
//  PasswordCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci
@testable import PingOrchestrate

final class PasswordCollectorTests: XCTestCase {
      
  func testCloseShouldClearPasswordWhenClearPasswordIsTrue() {
        let passwordCollector = PasswordCollector(with: [:])
        passwordCollector.value = "password"
        passwordCollector.clearPassword = true
        
        passwordCollector.close()
        
        XCTAssertEqual(passwordCollector.value, "")
    }
    
    func testCloseShouldNotClearPasswordWhenClearPasswordIsFalse() {
        let passwordCollector = PasswordCollector(with: [:])
        passwordCollector.value = "password"
        passwordCollector.clearPassword = false
        
        passwordCollector.close()
        
        XCTAssertEqual(passwordCollector.value, "password")
    }
    
    func testValidatesSuccessfullyWhenNoErrors() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "length": [
                    "min": 8,
                    "max": 20
                ],
                "minUniqueCharacters": 3,
                "maxRepeatedCharacters": 2,
                "minCharacters": [
                    "0123456789": 1,
                    "!@#$%^&*()": 1
                ]
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode =  MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        collector.value = "Valid1@Password"
        
        XCTAssertEqual(collector.validate(), [])
    }
    
    func testAddsInvalidLengthErrorWhenValueTooShort() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "length": [
                    "min": 8,
                    "max": 20
                ]
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        
        collector.value = "Short1@"
        
        XCTAssertEqual(collector.validate(), [.invalidLength(min: 8, max: 20)])
    }
    
    func testAddsUniqueCharacterErrorWhenNotEnoughUniqueCharacters() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "minUniqueCharacters": 5
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        
        collector.value = "aaa111@@@"
        
        XCTAssertEqual(collector.validate(), [.uniqueCharacter(min: 5)])
    }
    
    func testAddsMaxRepeatErrorWhenTooManyRepeatedCharacters() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "maxRepeatedCharacters": 2
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        
        collector.value = "aaabbbccc"
        
        XCTAssertEqual(collector.validate(), [.maxRepeat(max: 2)])
    }
    
    func testAddsMinCharactersErrorWhenNotEnoughDigits() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "minCharacters": [
                    "0123456789": 2
                ]
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        
        collector.value = "Password@1"
        
        XCTAssertEqual(collector.validate(), [.minCharacters(character: "0123456789", min: 2)])
    }
    
    func testAddsMinCharactersErrorWhenEnoughSpecialCharacters() {
        let input: [String: Any] = [
            "passwordPolicy": [
                "minCharacters": [
                    "!@#$%^&*()": 2
                ]
            ]
        ]
        
        let collector = PasswordCollector(with: [:])
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: input, actions: [])
        
        collector.value = "Password1!&"
        
        XCTAssertTrue(collector.validate().isEmpty)
    }
    
}

class MockContinueNode: ContinueNode { }
