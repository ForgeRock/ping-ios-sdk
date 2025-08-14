//
//  KbaCreateCallbackTests.swift
//  JourneyTests
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
        callback = KbaCreateCallback()

        let jsonString = """
        {
          "type": "KbaCreateCallback",
          "output": [
            {
              "name": "prompt",
              "value": "Purpose Message"
            },
            {
              "name": "predefinedQuestions",
              "value": [
                "What's your favorite color?",
                "what's your favorite place?",
                "Who was your first employer?"
              ]
            },
            {
              "name": "allowUserDefinedQuestions",
              "value": true
            }
          ],
          "input": [
            {
              "name": "IDToken1question",
              "value": ""
            },
            {
              "name": "IDToken1answer",
              "value": ""
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = KbaCreateCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
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

    func testInitValueWithIndividualProperties() {
        let newCallback = KbaCreateCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.prompt, value: "Create Security Question")
        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: ["Question 1", "Question 2"])
        newCallback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: false)

        XCTAssertEqual(newCallback.prompt, "Create Security Question")
        XCTAssertEqual(newCallback.predefinedQuestions, ["Question 1", "Question 2"])
        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
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

    func testInitValueWithUnknownProperties() {
        let newCallback = KbaCreateCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: ["array", "value"])

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.predefinedQuestions, [])
        XCTAssertEqual(newCallback.selectedQuestion, "")
        XCTAssertEqual(newCallback.selectedAnswer, "")
        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
    }

    func testEmptyPredefinedQuestions() {
        let newCallback = KbaCreateCallback()
        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: [String]())

        XCTAssertEqual(newCallback.predefinedQuestions, [])
    }

    func testSinglePredefinedQuestion() {
        let newCallback = KbaCreateCallback()
        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: ["Single question?"])

        XCTAssertEqual(newCallback.predefinedQuestions, ["Single question?"])
    }

    func testManyPredefinedQuestions() {
        let newCallback = KbaCreateCallback()
        let manyQuestions = (1...10).map { "Question \($0)?" }

        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: manyQuestions)

        XCTAssertEqual(newCallback.predefinedQuestions.count, 10)
        XCTAssertEqual(newCallback.predefinedQuestions[0], "Question 1?")
        XCTAssertEqual(newCallback.predefinedQuestions[9], "Question 10?")
    }

    func testAllowUserDefinedQuestionsBooleanValues() {
        let testCases = [true, false]

        for allowValue in testCases {
            let newCallback = KbaCreateCallback()
            newCallback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: allowValue)

            XCTAssertEqual(newCallback.allowUserDefinedQuestions, allowValue, "Failed for allowUserDefinedQuestions value: \(allowValue)")
        }
    }

    func testPayloadWithPredefinedQuestion() {
        // Test payload when user selects a predefined question
        callback.selectedQuestion = callback.predefinedQuestions[1] // "what's your favorite place?"
        callback.selectedAnswer = "Paris"

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            if let questionValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(questionValue, "what's your favorite place?")
            } else {
                XCTFail("Question value is not a string or not found")
            }

            if let answerValue = inputArray[1]["value"] as? String {
                XCTAssertEqual(answerValue, "Paris")
            } else {
                XCTFail("Answer value is not a string or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic KBA scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Please create a security question")
        callback.initValue(name: JourneyConstants.predefinedQuestions, value: [
            "What was the name of your first pet?",
            "In what city were you born?",
            "What was your childhood nickname?"
        ])
        callback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: true)

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Please create a security question")
        XCTAssertEqual(callback.predefinedQuestions.count, 3)
        XCTAssertTrue(callback.allowUserDefinedQuestions)
        XCTAssertEqual(callback.selectedQuestion, "")
        XCTAssertEqual(callback.selectedAnswer, "")

        // User selects a predefined question and provides answer
        callback.selectedQuestion = callback.predefinedQuestions[0] // "What was the name of your first pet?"
        callback.selectedAnswer = "Rex"

        // Test payload with user selection
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "What was the name of your first pet?")
            XCTAssertEqual(inputArray[1]["value"] as? String, "Rex")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = KbaCreateCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.predefinedQuestions, [])
        XCTAssertEqual(newCallback.selectedQuestion, "")
        XCTAssertEqual(newCallback.selectedAnswer, "")
        XCTAssertFalse(newCallback.allowUserDefinedQuestions)
    }

    func testQuestionsWithSpecialCharacters() {
        let newCallback = KbaCreateCallback()
        let specialQuestions = [
            "What's your mother's maiden name?",
            "In which city were you born?",
            "What was your first car's make & model?",
            "Who was your favorite teacher (first name)?",
            "What street did you grow up on?"
        ]

        newCallback.initValue(name: JourneyConstants.predefinedQuestions, value: specialQuestions)

        XCTAssertEqual(newCallback.predefinedQuestions, specialQuestions)
    }

    func testPayloadWithSpecialCharacters() {
        // Test payload with questions and answers containing special characters
        callback.selectedQuestion = "What's your mother's maiden name?"
        callback.selectedAnswer = "O'Connor-Smith"

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "What's your mother's maiden name?")
            XCTAssertEqual(inputArray[1]["value"] as? String, "O'Connor-Smith")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithLongAnswer() {
        let longAnswer = "This is a very long answer that contains multiple words and could be a complete sentence or even multiple sentences describing something in detail."

        callback.selectedQuestion = "Describe your first job"
        callback.selectedAnswer = longAnswer

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "Describe your first job")
            XCTAssertEqual(inputArray[1]["value"] as? String, longAnswer)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testUserDefinedQuestionWhenAllowed() {
        // Test scenario where user creates their own question when allowed
        XCTAssertTrue(callback.allowUserDefinedQuestions) // Should be true from setUp

        callback.selectedQuestion = "What was the first concert you attended?"
        callback.selectedAnswer = "The Beatles at Shea Stadium"

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "What was the first concert you attended?")
            XCTAssertEqual(inputArray[1]["value"] as? String, "The Beatles at Shea Stadium")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testUserDefinedQuestionWhenNotAllowed() {
        callback.initValue(name: JourneyConstants.allowUserDefinedQuestions, value: false)

        XCTAssertFalse(callback.allowUserDefinedQuestions)

        // User could still set a custom question (enforcement would be in UI/business logic)
        callback.selectedQuestion = "Custom question"
        callback.selectedAnswer = "Custom answer"

        // Payload would still work (validation is separate concern)
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "Custom question")
            XCTAssertEqual(inputArray[1]["value"] as? String, "Custom answer")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testSelectedPropertiesCanBeModified() {
        // Test that the selected properties can be changed multiple times
        XCTAssertEqual(callback.selectedQuestion, "")
        XCTAssertEqual(callback.selectedAnswer, "")

        callback.selectedQuestion = "First question"
        callback.selectedAnswer = "First answer"
        XCTAssertEqual(callback.selectedQuestion, "First question")
        XCTAssertEqual(callback.selectedAnswer, "First answer")

        callback.selectedQuestion = "Second question"
        callback.selectedAnswer = "Second answer"
        XCTAssertEqual(callback.selectedQuestion, "Second question")
        XCTAssertEqual(callback.selectedAnswer, "Second answer")
    }
}
