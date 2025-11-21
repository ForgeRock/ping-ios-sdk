//
//  BooleanAttributeInputCallbackTests.swift
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

class BooleanAttributeInputCallbackTests: XCTestCase {

    private var callback: BooleanAttributeInputCallback!

    override func setUp() {
        super.setUp()

        let jsonString = """
        {
          "type": "BooleanAttributeInputCallback",
          "output": [
            {
              "name": "name",
              "value": "custom_dummy"
            },
            {
              "name": "prompt",
              "value": "Dummy"
            },
            {
              "name": "required",
              "value": true
            },
            {
              "name": "policies",
              "value": {
                "policyRequirements": [
                  "VALID_TYPE"
                ],
                "fallbackPolicies": null,
                "name": "custom_dummy",
                "policies": [
                  {
                    "policyRequirements": [
                      "VALID_TYPE"
                    ],
                    "policyId": "valid-type",
                    "params": {
                      "types": [
                        "boolean"
                      ]
                    }
                  }
                ],
                "conditionalPolicies": null
              }
            },
            {
              "name": "failedPolicies",
              "value": []
            },
            {
              "name": "validateOnly",
              "value": false
            },
            {
              "name": "value",
              "value": true
            }
          ],
          "input": [
            {
              "name": "IDToken4",
              "value": true
            },
            {
              "name": "IDToken4validateOnly",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            // Initialize callback with parsed data
            callback = BooleanAttributeInputCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testBooleanAttributeInputCallbackInitializesValueCorrectlyFromJson() {
        // Test that the boolean value is initialized correctly from JSON
        XCTAssertTrue(callback.value)
    }

    func testPayloadReturnsCorrectly() {
        callback.value = false
        callback.validateOnly = true

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (value)
            if let boolValue = inputArray[0]["value"] as? Bool {
                XCTAssertFalse(boolValue)
            } else {
                XCTFail("Boolean value is not a Bool or not found")
            }

            // Check second input (validateOnly)
            if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                XCTAssertTrue(validateOnlyValue)
            } else {
                XCTFail("ValidateOnly value is not a Bool or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInheritsFromAttributeInputCallback() {
        // Test that properties from AttributeInputCallback are also initialized
        XCTAssertEqual(callback.name, "custom_dummy")
        XCTAssertEqual(callback.prompt, "Dummy")
        XCTAssertTrue(callback.required)

        // Test that properties from AbstractValidatedCallback are also initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)
    }

    func testInitValueWithBooleanTrue() {
        let newCallback = BooleanAttributeInputCallback()
        newCallback.initValue(name: JourneyConstants.value, value: true)

        XCTAssertTrue(newCallback.value)
    }

    func testInitValueWithBooleanFalse() {
        let newCallback = BooleanAttributeInputCallback()
        newCallback.initValue(name: JourneyConstants.value, value: false)

        XCTAssertFalse(newCallback.value)
    }

    func testInitValueWithInvalidType() {
        let newCallback = BooleanAttributeInputCallback()

        // Test with invalid type - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.value, value: "not a bool")

        // Should maintain default value
        XCTAssertFalse(newCallback.value)
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = BooleanAttributeInputCallback()

        // Test that properties from parent classes are also handled
        newCallback.initValue(name: JourneyConstants.name, value: "test_boolean")
        newCallback.initValue(name: JourneyConstants.prompt, value: "Test Boolean Prompt")
        newCallback.initValue(name: JourneyConstants.required, value: true)
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true)

        XCTAssertEqual(newCallback.name, "test_boolean")
        XCTAssertEqual(newCallback.prompt, "Test Boolean Prompt")
        XCTAssertTrue(newCallback.required)
        XCTAssertTrue(newCallback.validateOnly)
    }

    func testPayloadWithTrueValues() {
        callback.value = true
        callback.validateOnly = true

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (value)
            if let boolValue = inputArray[0]["value"] as? Bool {
                XCTAssertTrue(boolValue)
            } else {
                XCTFail("Boolean value is not a Bool or not found")
            }

            // Check second input (validateOnly)
            if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                XCTAssertTrue(validateOnlyValue)
            } else {
                XCTFail("ValidateOnly value is not a Bool or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testValuePropertyCanBeModified() {
        // Test that the value property can be changed after initialization
        XCTAssertTrue(callback.value) // Initially true from JSON

        callback.value = false
        XCTAssertFalse(callback.value)

        callback.value = true
        XCTAssertTrue(callback.value)
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = BooleanAttributeInputCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: true)

        // Should maintain default value
        XCTAssertFalse(newCallback.value)
    }

    func testCompleteInitializationScenario() {
        // Initialize all relevant properties
        callback.initValue(name: JourneyConstants.name, value: "accept_terms")
        callback.initValue(name: JourneyConstants.prompt, value: "Accept Terms and Conditions")
        callback.initValue(name: JourneyConstants.required, value: true)
        callback.initValue(name: JourneyConstants.value, value: false)
        callback.initValue(name: JourneyConstants.validateOnly, value: false)

        // Verify all properties are set correctly
        XCTAssertEqual(callback.name, "accept_terms")
        XCTAssertEqual(callback.prompt, "Accept Terms and Conditions")
        XCTAssertTrue(callback.required)
        XCTAssertFalse(callback.value)
        XCTAssertFalse(callback.validateOnly)

        // Test payload with these values
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? Bool, false)
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValue() {
        let newCallback = BooleanAttributeInputCallback()

        // Test that default value is false before any initialization
        XCTAssertFalse(newCallback.value)
    }
}
