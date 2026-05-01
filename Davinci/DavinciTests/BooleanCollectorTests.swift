//
//  BooleanCollectorTests.swift
//  Davinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingDavinci

class BooleanCollectorTests: XCTestCase {
    
    // MARK: - Parsing / Initialization
    
    func testInitializationWithEmptyDictionary() {
        let collector = BooleanCollector(with: [:])
        XCTAssertNotNil(collector)
        XCTAssertEqual(collector.key, "")
        XCTAssertEqual(collector.label, "")
        XCTAssertEqual(collector.required, false)
        XCTAssertEqual(collector.value, false)
        XCTAssertNil(collector.errorMessage)
        XCTAssertEqual(collector.appearance, .checkbox)
        XCTAssertNil(collector.richContent)
    }
    
    func testInitializationWithFullJSON() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "inputType": "BOOLEAN",
            "key": "single-checkbox-field",
            "label": "Welcome to Apple and Google",
            "required": true,
            "appearance": "CHECKBOX",
            "errorMessage": "Select the checkbox to continue.",
            "richContent": [
                "content": "Welcome to {{link1}} and {{link2}}",
                "replacements": [
                    "link1": [
                        "value": "Apple",
                        "href": "https://www.apple.com",
                        "type": "link",
                        "target": "_self"
                    ],
                    "link2": [
                        "value": "Google",
                        "href": "https://www.google.com",
                        "type": "link",
                        "target": "_blank"
                    ]
                ]
            ]
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertEqual(collector.type, "SINGLE_CHECKBOX")
        XCTAssertEqual(collector.key, "single-checkbox-field")
        XCTAssertEqual(collector.label, "Welcome to Apple and Google")
        XCTAssertEqual(collector.required, true)
        XCTAssertEqual(collector.appearance, .checkbox)
        XCTAssertEqual(collector.errorMessage, "Select the checkbox to continue.")
        XCTAssertEqual(collector.value, false)
        
        // Rich content
        XCTAssertNotNil(collector.richContent)
        XCTAssertEqual(collector.richContent?.content, "Welcome to {{link1}} and {{link2}}")
        XCTAssertEqual(collector.richContent?.replacements.count, 2)
        
        let link1 = collector.richContent?.replacements["link1"]
        XCTAssertEqual(link1?.value, "Apple")
        XCTAssertEqual(link1?.href, "https://www.apple.com")
        XCTAssertEqual(link1?.type, "link")
        XCTAssertEqual(link1?.target, "_self")
        
        let link2 = collector.richContent?.replacements["link2"]
        XCTAssertEqual(link2?.value, "Google")
        XCTAssertEqual(link2?.href, "https://www.google.com")
        XCTAssertEqual(link2?.type, "link")
        XCTAssertEqual(link2?.target, "_blank")
    }
    
    func testInitializationWithSwitchAppearance() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "key": "toggle-field",
            "label": "Enable notifications",
            "required": false,
            "appearance": "SWITCH"
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertEqual(collector.appearance, .switch
        )
    }
    
    func testInitializationWithoutAppearanceDefaultsToCheckbox() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "key": "checkbox-field",
            "label": "Agree",
            "required": true
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertEqual(collector.appearance, .checkbox)
    }
    
    func testInitializationWithoutErrorMessage() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "key": "checkbox-field",
            "label": "Subscribe to newsletter",
            "required": false
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertEqual(collector.required, false)
        XCTAssertNil(collector.errorMessage)
    }
    
    func testInitializationWithoutRichContent() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "key": "checkbox-field",
            "label": "I agree",
            "required": true,
            "errorMessage": "Required"
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertNil(collector.richContent)
        XCTAssertEqual(collector.errorMessage, "Required")
    }
    
    func testInitializationWithRichContentNoReplacements() {
        let input: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "key": "checkbox-field",
            "label": "Agree",
            "required": true,
            "richContent": [
                "content": "Plain text content"
            ]
        ]
        
        let collector = BooleanCollector(with: input)
        XCTAssertNotNil(collector.richContent)
        XCTAssertEqual(collector.richContent?.content, "Plain text content")
        XCTAssertEqual(collector.richContent?.replacements.count, 0)
    }
    
    // MARK: - Value Handling
    
    func testValueDefaultsToFalse() {
        let collector = BooleanCollector(with: [:])
        XCTAssertEqual(collector.value, false)
    }
    
    func testSetValueToTrue() {
        let collector = BooleanCollector(with: [:])
        collector.value = true
        XCTAssertEqual(collector.value, true)
    }
    
    func testInitializeWithBoolValue() {
        let collector = BooleanCollector(with: [:])
        collector.initialize(with: true)
        XCTAssertEqual(collector.value, true)
    }
    
    func testInitializeWithFalseValue() {
        let collector = BooleanCollector(with: [:])
        collector.value = true
        collector.initialize(with: false)
        XCTAssertEqual(collector.value, false)
    }
    
    func testInitializeWithNonBoolValueIsIgnored() {
        let collector = BooleanCollector(with: [:])
        collector.initialize(with: "true")
        XCTAssertEqual(collector.value, false)
    }
    
    // MARK: - Payload
    
    func testPayloadReturnsFalseWhenUnchecked() {
        let collector = BooleanCollector(with: [:])
        XCTAssertEqual(collector.payload(), false)
    }
    
    func testPayloadReturnsTrueWhenChecked() {
        let collector = BooleanCollector(with: [:])
        collector.value = true
        XCTAssertEqual(collector.payload(), true)
    }
    
    // MARK: - Validation
    
    func testValidateRequiredAndUncheckedReturnsError() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": true
        ]
        let collector = BooleanCollector(with: input)
        
        let errors = collector.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first, .required)
    }
    
    func testValidateRequiredAndCheckedReturnsNoError() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": true
        ]
        let collector = BooleanCollector(with: input)
        collector.value = true
        
        let errors = collector.validate()
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testValidateNotRequiredAndUncheckedReturnsNoError() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": false
        ]
        let collector = BooleanCollector(with: input)
        
        let errors = collector.validate()
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testValidateRequiredWithCustomErrorMessage() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": true,
            "errorMessage": "Select the checkbox to continue."
        ]
        let collector = BooleanCollector(with: input)
        
        let errors = collector.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.errorMessage, "Select the checkbox to continue.")
    }
    
    func testValidateRequiredWithEmptyErrorMessageFallsBackToRequired() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": true,
            "errorMessage": ""
        ]
        let collector = BooleanCollector(with: input)
        
        let errors = collector.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first, .required)
    }
    
    func testValidateRequiredCheckedWithErrorMessageReturnsNoError() {
        let input: [String: Any] = [
            "key": "agree",
            "label": "Agree",
            "required": true,
            "errorMessage": "Select the checkbox to continue."
        ]
        let collector = BooleanCollector(with: input)
        collector.value = true
        
        let errors = collector.validate()
        XCTAssertTrue(errors.isEmpty)
    }
}
