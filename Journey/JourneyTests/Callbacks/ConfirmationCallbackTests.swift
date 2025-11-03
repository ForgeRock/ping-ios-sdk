//
//  ConfirmationCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class ConfirmationCallbackTests: XCTestCase {

    private var callback: ConfirmationCallback!

    override func setUp() {
        super.setUp()
        callback = ConfirmationCallback()

        let jsonString = """
        {
          "type": "ConfirmationCallback",
          "output": [
            {
              "name": "prompt",
              "value": "Please confirm your choice"
            },
            {
              "name": "messageType",
              "value": 0
            },
            {
              "name": "options",
              "value": [
                "Yes",
                "No"
              ]
            },
            {
              "name": "optionType",
              "value": -1
            },
            {
              "name": "defaultOption",
              "value": 1
            }
          ],
          "input": [
            {
              "name": "IDToken2",
              "value": 100
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            // Set up the original json property to simulate the initial state
            callback = ConfirmationCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "Please confirm your choice")
        XCTAssertEqual(callback.messageType, MessageType.information)
        XCTAssertEqual(callback.options, ["Yes", "No"])
        XCTAssertEqual(callback.optionType, OptionType.unspecified)
        XCTAssertEqual(callback.defaultOption, OptionType.yesNoCancel)
    }

    func testPayloadReturnsCorrectly() {
        callback.selectedIndex = 1

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Int {
            XCTAssertEqual(value, 1)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadNotExplicitlySet() {
        // Don't set selectedIndex (it should remain nil)

        let payload = callback.payload()

        // Should return the original json property
        XCTAssertNotNil(payload)

        // Verify it returns the original json with the default value (100)
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Int {
            XCTAssertEqual(value, 100)
        } else {
            XCTFail("Payload structure is not as expected when selectedIndex is not set")
        }
    }

    func testOptionTypeEnumMapping() {
        let testCases: [(Int, OptionType)] = [
            (-1, .unspecified),
            (0, .yesNo),
            (1, .yesNoCancel),
            (2, .okCancel),
            (999, .unknown) // Unknown value should default to .unknown
        ]

        for (rawValue, expectedType) in testCases {
            let newCallback = ConfirmationCallback()
            newCallback.initValue(name: JourneyConstants.optionType, value: rawValue)

            XCTAssertEqual(newCallback.optionType, expectedType, "Failed for optionType: \(rawValue)")
        }
    }

    func testMessageTypeEnumMapping() {
        // Assuming MessageType enum has similar values to Android constants
        let testCases: [(Int, MessageType)] = [
            (0, .information),
            (1, .warning),
            (2, .error)
        ]

        for (rawValue, expectedType) in testCases {
            let newCallback = ConfirmationCallback()
            newCallback.initValue(name: JourneyConstants.messageType, value: rawValue)

            XCTAssertEqual(newCallback.messageType, expectedType, "Failed for messageType: \(rawValue)")
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = ConfirmationCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.messageType, value: "invalid") // Invalid type
        newCallback.initValue(name: JourneyConstants.options, value: "not an array") // Invalid type
        newCallback.initValue(name: JourneyConstants.optionType, value: "invalid") // Invalid type
        newCallback.initValue(name: JourneyConstants.defaultOption, value: "invalid") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
        XCTAssertEqual(newCallback.options, [])
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)
        XCTAssertEqual(newCallback.defaultOption, OptionType.unspecified)
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = ConfirmationCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
        XCTAssertEqual(newCallback.options, [])
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)
        XCTAssertEqual(newCallback.defaultOption, OptionType.unspecified)
        XCTAssertNil(newCallback.selectedIndex)
    }

    func testSelectedIndexOptionalBehavior() {
        let newCallback = ConfirmationCallback()

        // Initially should be nil
        XCTAssertNil(newCallback.selectedIndex)

        // Can be set to a value
        newCallback.selectedIndex = 0
        XCTAssertEqual(newCallback.selectedIndex, 0)

        // Can be set back to nil
        newCallback.selectedIndex = nil
        XCTAssertNil(newCallback.selectedIndex)
    }

    func testPayloadWithDifferentSelections() {
        let testIndices = [0, 1, 2, -1, 999]

        for testIndex in testIndices {
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

    func testDifferentOptionTypes() {
        let optionTypeTests: [(OptionType, [String])] = [
            (.yesNo, ["Yes", "No"]),
            (.yesNoCancel, ["Yes", "No", "Cancel"]),
            (.okCancel, ["OK", "Cancel"]),
            (.unspecified, ["Custom1", "Custom2", "Custom3"])
        ]

        for (optionType, expectedOptions) in optionTypeTests {
            let newCallback = ConfirmationCallback()
            newCallback.initValue(name: JourneyConstants.optionType, value: optionType.rawValue)
            newCallback.initValue(name: JourneyConstants.options, value: expectedOptions)

            XCTAssertEqual(newCallback.optionType, optionType)
            XCTAssertEqual(newCallback.options, expectedOptions)
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Do you want to save changes?")
        callback.initValue(name: JourneyConstants.messageType, value: 1) // WARNING
        callback.initValue(name: JourneyConstants.optionType, value: 1) // YES_NO_CANCEL
        callback.initValue(name: JourneyConstants.options, value: ["Yes", "No", "Cancel"])
        callback.initValue(name: JourneyConstants.defaultOption, value: 2) // Cancel as default

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Do you want to save changes?")
        XCTAssertEqual(callback.messageType, MessageType.warning)
        XCTAssertEqual(callback.optionType, OptionType.yesNoCancel)
        XCTAssertEqual(callback.options, ["Yes", "No", "Cancel"])
        XCTAssertEqual(callback.defaultOption, OptionType.okCancel)
        XCTAssertNil(callback.selectedIndex) // Should be nil until user makes selection

        // User makes a selection
        callback.selectedIndex = 0 // "Yes"

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
        let newCallback = ConfirmationCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.options, [])
        XCTAssertEqual(newCallback.defaultOption, OptionType.unspecified)
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
        XCTAssertNil(newCallback.selectedIndex)
    }

    func testEmptyOptionsArray() {
        let newCallback = ConfirmationCallback()
        newCallback.initValue(name: JourneyConstants.options, value: [String]())

        XCTAssertEqual(newCallback.options, [])
    }

    func testOptionsWithSpecialCharacters() {
        let newCallback = ConfirmationCallback()
        let specialOptions = ["Oui (Français)", "Nein (Deutsch)", "はい (Japanese)", "Cancel ❌"]

        newCallback.initValue(name: JourneyConstants.options, value: specialOptions)

        XCTAssertEqual(newCallback.options, specialOptions)
    }

    func testInvalidEnumValues() {
        let newCallback = ConfirmationCallback()

        // Test with invalid enum values
        newCallback.initValue(name: JourneyConstants.optionType, value: 999)
        newCallback.initValue(name: JourneyConstants.messageType, value: 999)

        // Should default to .unknown
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testNegativeDefaultOption() {
        let newCallback = ConfirmationCallback()
        newCallback.initValue(name: JourneyConstants.defaultOption, value: -5)

        XCTAssertEqual(newCallback.defaultOption, OptionType.unspecified)
    }
}
