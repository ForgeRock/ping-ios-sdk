// 
//  PasswordCollectorTests.swift
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
        let fieldJson = fieldJsonWithPasswordPolicy([
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
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        collector.value = "Valid1@Password"
        
        XCTAssertEqual(collector.validate(), [])
    }
    
    func testAddsInvalidLengthErrorWhenValueTooShort() {
        let fieldJson = fieldJsonWithPasswordPolicy([
            "length": [
                "min": 8,
                "max": 20
            ]
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        collector.value = "Short1@"
        
        XCTAssertEqual(collector.validate(), [.invalidLength(min: 8, max: 20)])
    }
    
    func testAddsUniqueCharacterErrorWhenNotEnoughUniqueCharacters() {
        let fieldJson = fieldJsonWithPasswordPolicy([
            "minUniqueCharacters": 5
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        collector.value = "aaa111@@@"
        
        XCTAssertEqual(collector.validate(), [.uniqueCharacter(min: 5)])
    }
    
    func testAddsMaxRepeatErrorWhenTooManyRepeatedCharacters() {
        let fieldJson = fieldJsonWithPasswordPolicy([
            "maxRepeatedCharacters": 2
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        collector.value = "aaabbbccc"
        
        XCTAssertEqual(collector.validate(), [.maxRepeat(max: 2)])
    }
    
    func testAddsMinCharactersErrorWhenNotEnoughDigits() {
        let fieldJson = fieldJsonWithPasswordPolicy([
            "minCharacters": [
                "0123456789": 2
            ]
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        collector.value = "Password@1"
        
        XCTAssertEqual(collector.validate(), [.minCharacters(character: "0123456789", min: 2)])
    }
    
    func testValidatesSuccessfullyWhenEnoughSpecialCharacters() {
        let fieldJson = fieldJsonWithPasswordPolicy([
            "minCharacters": [
                "!@#$%^&*()": 2
            ]
        ])
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        collector.value = "Password1!&"
        
        XCTAssertTrue(collector.validate().isEmpty)
    }
    
    func testShouldInitializeDefaultValue() {
        let input = "test"
        let collector = PasswordCollector(with: [:])
        collector.initialize(with: input)
        XCTAssertEqual("test", collector.value)
    }
    
    func testPasswordPolicyReadFromComponentScope() {
        let fieldJson: [String: Any] = [
            "type": "PASSWORD_VERIFY",
            "key": "user.password",
            "label": "Password",
            "passwordPolicy": [
                "name": "Standard",
                "length": [
                    "min": 8,
                    "max": 255
                ],
                "minUniqueCharacters": 5,
                "maxRepeatedCharacters": 2,
                "minCharacters": [
                    "0123456789": 1,
                    "ABCDEFGHIJKLMNOPQRSTUVWXYZ": 1,
                    "abcdefghijklmnopqrstuvwxyz": 1,
                    "~!@#$%^&*()-_=+[]{}|;:,.<>/?": 1
                ]
            ]
        ]
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        
        let policy = collector.passwordPolicy()
        XCTAssertNotNil(policy)
        XCTAssertEqual("Standard", policy?.name)
        XCTAssertEqual(8, policy?.length.min)
        XCTAssertEqual(255, policy?.length.max)
        XCTAssertEqual(5, policy?.minUniqueCharacters)
        XCTAssertEqual(2, policy?.maxRepeatedCharacters)
        XCTAssertTrue(policy?.minCharacters.keys.contains("0123456789") ?? false)
        XCTAssertTrue(policy?.minCharacters.keys.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ") ?? false)
        XCTAssertTrue(policy?.minCharacters.keys.contains("abcdefghijklmnopqrstuvwxyz") ?? false)
        XCTAssertTrue(policy?.minCharacters.keys.contains("~!@#$%^&*()-_=+[]{}|;:,.<>/?") ?? false)
        
        // A valid password should produce no errors
        collector.value = "Valid1@Pass"
        XCTAssertEqual(collector.validate(), [])
        
        // A password that is too short should produce an InvalidLength error
        collector.value = "Sh0rt!"
        XCTAssertTrue(collector.validate().contains(.invalidLength(min: 8, max: 255)))
    }
    
    func testNoValidationErrorsWhenFormHasNoPasswordPolicy() {
        let fieldJson: [String: Any] = [
            "type": "PASSWORD_VERIFY",
            "key": "user.password",
            "label": "Password"
        ]
        
        let collector = PasswordCollector(with: fieldJson)
        collector.continueNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: [:], actions: [])
        collector.value = "any"
        
        XCTAssertNil(collector.passwordPolicy())
        XCTAssertEqual(collector.validate(), [])
    }
    
    func testFallbackToGlobalScopePasswordPolicy() {
        // No passwordPolicy in field JSON
        let collector = PasswordCollector(with: [:])
        
        // passwordPolicy provided at the global scope (top-level input)
        let globalInput: [String: Any] = [
            "passwordPolicy": [
                "length": [
                    "min": 10,
                    "max": 50
                ]
            ]
        ]
        let mockNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: globalInput, actions: [])
        collector.continueNode = mockNode
        
        let policy = collector.passwordPolicy()
        XCTAssertNotNil(policy)
        XCTAssertEqual(10, policy?.length.min)
        XCTAssertEqual(50, policy?.length.max)
        
        collector.value = "Short"
        XCTAssertTrue(collector.validate().contains(.invalidLength(min: 10, max: 50)))
    }
    
    func testComponentScopeTakesPrecedenceOverGlobalScope() {
        // passwordPolicy in field JSON (component scope)
        let fieldJson: [String: Any] = [
            "passwordPolicy": [
                "length": [
                    "min": 8,
                    "max": 100
                ]
            ]
        ]
        let collector = PasswordCollector(with: fieldJson)
        
        // Different passwordPolicy at the global scope
        let globalInput: [String: Any] = [
            "passwordPolicy": [
                "length": [
                    "min": 20,
                    "max": 50
                ]
            ]
        ]
        let mockNode = MockContinueNode(context: FlowContext(flowContext: SharedContext()), workflow: Workflow(config: WorkflowConfig()), input: globalInput, actions: [])
        collector.continueNode = mockNode
        
        let policy = collector.passwordPolicy()
        XCTAssertNotNil(policy)
        // Component scope should win
        XCTAssertEqual(8, policy?.length.min)
        XCTAssertEqual(100, policy?.length.max)
    }
    
    // MARK: - Helpers
    
    /// Creates a field-level JSON dictionary with a PASSWORD_VERIFY type containing the given password policy.
    private func fieldJsonWithPasswordPolicy(_ policy: [String: Any]) -> [String: Any] {
        return [
            "type": "PASSWORD_VERIFY",
            "passwordPolicy": policy
        ]
    }
}

class MockContinueNode: ContinueNode, @unchecked Sendable { }
