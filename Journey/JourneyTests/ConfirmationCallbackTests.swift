//
//  ConfirmationCallbackTests.swift
//  Journey
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
        let json: [String : Any] = [
            "type": "ConfirmationCallback",
            "output": [
                ["name": "prompt", "value": "Please confirm your choice"],
                ["name": "messageType", "value": 0],
                ["name": "options", "value": ["Yes", "No"]],
                ["name": "optionType", "value": -1],
                ["name": "defaultOption", "value": 1]
            ],
            "input": [
                ["name": "IDToken2", "value": 100]
            ]
        ]

        callback = ConfirmationCallback()
        _ = callback.initialize(with: json)
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "Please confirm your choice")
        XCTAssertEqual(callback.messageType, MessageType.information)
        XCTAssertEqual(callback.options, ["Yes", "No"])
        XCTAssertEqual(callback.optionType, OptionType.unspecified)
        XCTAssertEqual(callback.defaultOption, 1)
        XCTAssertNil(callback.selectedIndex)
    }

    func testPayloadReturnsCorrectlyWhenSelectedIndexSet() {
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
        XCTAssertEqual(newCallback.defaultOption, -1)
    }

    func testInitValueWithUnknownName() {
        let newCallback = ConfirmationCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
        XCTAssertEqual(newCallback.options, [])
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)
        XCTAssertEqual(newCallback.defaultOption, -1)
    }

    func testOptionTypeEnum() {
        let newCallback = ConfirmationCallback()

        // Test unknown value - should remain unknown (default)
        newCallback.initValue(name: JourneyConstants.optionType, value: 999)
        XCTAssertEqual(newCallback.optionType, OptionType.unknown)

        // Test various option type values
        newCallback.initValue(name: JourneyConstants.optionType, value: 0)
        XCTAssertEqual(newCallback.optionType, OptionType.yesNo)

        newCallback.initValue(name: JourneyConstants.optionType, value: 1)
        XCTAssertEqual(newCallback.optionType, OptionType.yesNoCancel)

        newCallback.initValue(name: JourneyConstants.optionType, value: 2)
        XCTAssertEqual(newCallback.optionType, OptionType.okCancel)

        newCallback.initValue(name: JourneyConstants.optionType, value: -1)
        XCTAssertEqual(newCallback.optionType, OptionType.unspecified)
    }
}
