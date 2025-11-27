//
//  NameCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingJourneyPlugin
@testable import PingJourney

class NameCallbackTests: XCTestCase {

    private var callback: NameCallback!
    
    override func setUp() {
        super.setUp()
        callback = NameCallback()

        let jsonString = """
        {
          "output": [
            {
              "name": "prompt",
              "value": "Enter your name"
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": ""
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = NameCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesPromptWhenJsonElementContainsPrompt() {
        XCTAssertEqual(callback.prompt, "Enter your name")
    }

    func testPayloadReturnsInputNameCorrectly() {
        callback.name = "John Doe"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "John Doe")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithEmptyName() {
        // Don't set name (should remain empty string)

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testNameCanBeModified() {
        // Test that the name property can be changed after initialization
        XCTAssertEqual(callback.name, "") // Initially empty

        callback.name = "Jane Smith"
        XCTAssertEqual(callback.name, "Jane Smith")

        callback.name = "Bob Johnson"
        XCTAssertEqual(callback.name, "Bob Johnson")

        callback.name = ""
        XCTAssertEqual(callback.name, "")
    }

    func testInitValueWithPrompt() {
        let newCallback = NameCallback()
        newCallback.initValue(name: JourneyConstants.prompt, value: "Please enter your full name")

        XCTAssertEqual(newCallback.prompt, "Please enter your full name")
    }

    func testInitValueWithInvalidType() {
        let newCallback = NameCallback()

        // Test with invalid type - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type

        // Should maintain default value
        XCTAssertEqual(newCallback.prompt, "")
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = NameCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.name, "")
    }

    func testPayloadWithDifferentNames() {
        let testNames = [
            "",
            "John",
            "John Doe",
            "Mary-Jane Watson",
            "José María García",
            "李小明",
            "محمد أحمد",
            "Jean-Baptiste O'Connor",
            "Name with spaces and numbers 123",
            "VeryLongNameThatCouldPotentiallyBeEnteredBySomeoneWithAnUnusuallyLongName"
        ]

        for testName in testNames {
            callback.name = testName
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testName, "Failed for name: \(testName)")
            } else {
                XCTFail("Payload structure is not as expected for name: \(testName)")
            }
        }
    }

    func testPromptWithDifferentValues() {
        let promptTestCases = [
            "",
            "Name",
            "Enter your name",
            "Please provide your full name",
            "What is your name?",
            "Nom (French)",
            "Name with émojis 👤",
            "Very long prompt that asks for the user's complete legal name as it appears on official documents"
        ]

        for testPrompt in promptTestCases {
            let newCallback = NameCallback()
            newCallback.initValue(name: JourneyConstants.prompt, value: testPrompt)

            XCTAssertEqual(newCallback.prompt, testPrompt, "Failed for prompt: \(testPrompt)")
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize in a realistic user registration scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Enter your full legal name")

        // Verify prompt is set correctly
        XCTAssertEqual(callback.prompt, "Enter your full legal name")
        XCTAssertEqual(callback.name, "") // Default value

        // User enters their name
        callback.name = "Alexandra Thompson"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "Alexandra Thompson")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = NameCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.name, "")
    }

    func testNameWithWhitespace() {
        // Test names with various whitespace scenarios
        let whitespaceTestCases = [
            " ",
            "  ",
            " John ",
            " John Doe ",
            "John  Doe", // Double space
            "\tJohn\t", // Tabs
            "\nJohn\n"  // Newlines
        ]

        for testName in whitespaceTestCases {
            callback.name = testName
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testName, "Failed to preserve whitespace for: '\(testName)'")
            } else {
                XCTFail("Payload structure is not as expected for whitespace test")
            }
        }
    }
}
