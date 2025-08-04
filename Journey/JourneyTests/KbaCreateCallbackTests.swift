//
//  KbaCreateCallbackTests.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class KbaCreateCallbackTests: XCTestCase {

    private var callback: KbaCreateCallback!

    override func setUp() {
        super.setUp()

        // Set up the original json property to simulate the initial state
        // This would normally be set by the parent AbstractCallback during initialization
        let json: [String: Any] = [
            "type": "KbaCreateCallback",
            "output": [
                ["name": "prompt", "value": "Purpose Message"],
                ["name": "predefinedQuestions", "value": [
                    "What's your favorite color?",
                    "what's your favorite place?",
                    "Who was your first employer?"
                ]],
                ["name": "allowUserDefinedQuestions", "value": true]
            ],
            "input": [
                ["name": "IDToken1question", "value": ""],
                ["name": "IDToken1answer", "value": ""]
            ]
        ]

        callback = KbaCreateCallback()
        _ = callback.initialize(with: json)
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "Purpose Message")
        XCTAssertEqual(callback.predefinedQuestions, [
            "What's your favorite color?",
            "what's your favorite place?",
            "Who was your first employer?"
        ])
        XCTAssertEqual(callback.selectedQuestion, "")
        XCTAssertEqual(callback.selectedAnswer, "")
        XCTAssertTrue(callback.allowUserDefinedQuestions)
    }

    func testPayloadReturnsCorrectly() {
        callback.selectedQuestion = "What's your favorite color?"
        callback.selectedAnswer = "Blue"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (question)
            if let questionValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(questionValue, "What's your favorite color?")
            } else {
                XCTFail("Question value is not a string or not found")
            }

            // Check second input (answer)
            if let answerValue = inputArray[1]["value"] as? String {
                XCTAssertEqual(answerValue, "Blue")
            } else {
                XCTFail("Answer value is not a string or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithEmptyValues() {
        // Don't set selectedQuestion and selectedAnswer (they should remain empty strings)

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload contains empty strings
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (question)
            if let questionValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(questionValue, "")
            } else {
                XCTFail("Question value is not a string or not found")
            }

            // Check second input (answer)
            if let answerValue = inputArray[1]["value"] as? String {
                XCTAssertEqual(answerValue, "")
            } else {
                XCTFail("Answer value is not a string or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = KbaCreateCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: "not an array") // Invalid type
        newCallback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: "not a bool") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.predefinedQuestions, [])
        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
    }

    func testInitValueWithUnknownName() {
        let newCallback = KbaCreateCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.predefinedQuestions, [])
        XCTAssertEqual(newCallback.selectedQuestion, "")
        XCTAssertEqual(newCallback.selectedAnswer, "")
        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
    }

    func testAllowUserDefinedQuestionsFalse() {
        let newCallback = KbaCreateCallback()

        // Test with allowUserDefinedQuestions set to false
        newCallback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: false)

        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
    }

    func testEmptyPredefinedQuestions() {
        let newCallback = KbaCreateCallback()

        // Test with empty predefined questions array
        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: [String]())

        XCTAssertEqual(newCallback.predefinedQuestions, [])
    }

    func testUserInteractionProperties() {
        // Test that user interaction properties can be modified
        callback.selectedQuestion = "Custom question?"
        callback.selectedAnswer = "Custom answer"
        callback.allowUserDefinedQuestions = false

        XCTAssertEqual(callback.selectedQuestion, "Custom question?")
        XCTAssertEqual(callback.selectedAnswer, "Custom answer")
        XCTAssertFalse(callback.allowUserDefinedQuestions)
    }

    func testPayloadWithCustomQuestion() {
        // Test payload when user provides a custom question
        callback.selectedQuestion = "What is your pet's name?"
        callback.selectedAnswer = "Fluffy"

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            if let questionValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(questionValue, "What is your pet's name?")
            } else {
                XCTFail("Question value is not a string or not found")
            }

            if let answerValue = inputArray[1]["value"] as? String {
                XCTAssertEqual(answerValue, "Fluffy")
            } else {
                XCTFail("Answer value is not a string or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }
}
