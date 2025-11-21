//
//  ChoiceCallbackTests.swift
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

class ChoiceCallbackTests: XCTestCase {

    private var callback: ChoiceCallback!

    override func setUp() {
        super.setUp()
        callback = ChoiceCallback()

        let jsonString = """
        {
          "type": "ChoiceCallback",
          "output": [
            {
              "name": "prompt",
              "value": "Choose an option"
            },
            {
              "name": "choices",
              "value": [
                "Option 1",
                "Option 2",
                "Option 3"
              ]
            },
            {
              "name": "defaultChoice",
              "value": 1
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": 1
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            callback = ChoiceCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesPromptAndChoicesCorrectly() {
        XCTAssertEqual(callback.defaultChoice, 1)
        XCTAssertEqual(callback.selectedIndex, 1) // Should be set to defaultChoice
        XCTAssertEqual(callback.prompt, "Choose an option")
        XCTAssertEqual(callback.choices, ["Option 1", "Option 2", "Option 3"])
    }

    func testPayloadReturnsSelectedChoiceIndexCorrectly() {
        callback.selectedIndex = 2

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Int {
            XCTAssertEqual(value, 2)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = ChoiceCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.prompt, value: "Select your preference")
        newCallback.initValue(name: JourneyConstants.choices, value: ["Choice A", "Choice B"])
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: 0)

        XCTAssertEqual(newCallback.prompt, "Select your preference")
        XCTAssertEqual(newCallback.choices, ["Choice A", "Choice B"])
        XCTAssertEqual(newCallback.defaultChoice, 0)
        XCTAssertEqual(newCallback.selectedIndex, 0) // Should match defaultChoice
    }

    func testDefaultChoiceSetsSelectedIndex() {
        let newCallback = ChoiceCallback()

        // Test that setting defaultChoice also sets selectedIndex
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: 3)

        XCTAssertEqual(newCallback.defaultChoice, 3)
        XCTAssertEqual(newCallback.selectedIndex, 3)
    }

    func testSelectedIndexCanBeModified() {
        // Test that selectedIndex can be changed after initialization
        XCTAssertEqual(callback.selectedIndex, 1) // Initial value from defaultChoice

        callback.selectedIndex = 0
        XCTAssertEqual(callback.selectedIndex, 0)

        callback.selectedIndex = 2
        XCTAssertEqual(callback.selectedIndex, 2)
    }

    func testPayloadWithDefaultSelection() {
        // Don't modify selectedIndex - use default
        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Int {
            XCTAssertEqual(value, 1) // Should be the defaultChoice value
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithDifferentSelections() {
        let testCases = [0, 1, 2, 5, -1] // Including edge cases

        for testIndex in testCases {
            callback.selectedIndex = testIndex
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? Int {
                XCTAssertEqual(value, testIndex, "Failed for selectedIndex: \(testIndex)")
            } else {
                XCTFail("Payload structure is not as expected for selectedIndex: \(testIndex)")
            }
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = ChoiceCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.choices, value: "not an array") // Invalid type
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: "not an int") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.choices, [])
        XCTAssertEqual(newCallback.defaultChoice, 0)
        XCTAssertEqual(newCallback.selectedIndex, 0)
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = ChoiceCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: 123)

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.choices, [])
        XCTAssertEqual(newCallback.defaultChoice, 0)
        XCTAssertEqual(newCallback.selectedIndex, 0)
    }

    func testEmptyChoicesArray() {
        let newCallback = ChoiceCallback()
        newCallback.initValue(name: JourneyConstants.choices, value: [String]())

        XCTAssertEqual(newCallback.choices, [])
    }

    func testSingleChoice() {
        let newCallback = ChoiceCallback()
        newCallback.initValue(name: JourneyConstants.prompt, value: "Only one choice")
        newCallback.initValue(name: JourneyConstants.choices, value: ["Only Option"])
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: 0)

        XCTAssertEqual(newCallback.prompt, "Only one choice")
        XCTAssertEqual(newCallback.choices, ["Only Option"])
        XCTAssertEqual(newCallback.defaultChoice, 0)
        XCTAssertEqual(newCallback.selectedIndex, 0)
    }

    func testManyChoices() {
        let newCallback = ChoiceCallback()
        let manyChoices = (1...10).map { "Choice \($0)" }

        newCallback.initValue(name: JourneyConstants.choices, value: manyChoices)
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: 7)

        XCTAssertEqual(newCallback.choices.count, 10)
        XCTAssertEqual(newCallback.choices[0], "Choice 1")
        XCTAssertEqual(newCallback.choices[9], "Choice 10")
        XCTAssertEqual(newCallback.defaultChoice, 7)
        XCTAssertEqual(newCallback.selectedIndex, 7)
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a real scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Select your country")
        callback.initValue(name: JourneyConstants.choices, value: ["USA", "Canada", "Mexico", "Other"])
        callback.initValue(name: JourneyConstants.defaultChoice, value: 3) // "Other"

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Select your country")
        XCTAssertEqual(callback.choices, ["USA", "Canada", "Mexico", "Other"])
        XCTAssertEqual(callback.defaultChoice, 3)
        XCTAssertEqual(callback.selectedIndex, 3)

        // User changes selection
        callback.selectedIndex = 0 // "USA"

        // Test payload with user selection
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Int {
            XCTAssertEqual(value, 0)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = ChoiceCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.choices, [])
        XCTAssertEqual(newCallback.defaultChoice, 0)
        XCTAssertEqual(newCallback.selectedIndex, 0)
    }

    func testChoicesWithSpecialCharacters() {
        let newCallback = ChoiceCallback()
        let specialChoices = ["Choice with spaces", "Choice-with-dashes", "Choice_with_underscores", "Choice with émojis 🎉"]

        newCallback.initValue(name: JourneyConstants.choices, value: specialChoices)

        XCTAssertEqual(newCallback.choices, specialChoices)
    }

    func testNegativeDefaultChoice() {
        let newCallback = ChoiceCallback()
        newCallback.initValue(name: JourneyConstants.defaultChoice, value: -1)

        XCTAssertEqual(newCallback.defaultChoice, -1)
        XCTAssertEqual(newCallback.selectedIndex, -1) // Should still be set even if negative
    }
}
