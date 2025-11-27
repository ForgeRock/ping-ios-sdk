//
//  AttributeInputCallbackTests.swift
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

class AttributeInputCallbackTests: XCTestCase {

    private var callback: AttributeInputCallback!

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
            callback = AttributeInputCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testAttributeInputCallbackCorrectlyFromJson() {
        XCTAssertEqual(callback.name, "custom_dummy")
        XCTAssertEqual(callback.prompt, "Dummy")
        XCTAssertTrue(callback.required)
    }

    func testInheritsFromAbstractValidatedCallback() {
        // Test that properties from AbstractValidatedCallback are also initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)

        // Test policies structure
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements.count, 1)
            XCTAssertEqual(policyRequirements[0], "VALID_TYPE")
        } else {
            XCTFail("Failed to parse policyRequirements")
        }

        if let policiesArray = callback.policies["policies"] as? [[String: Any]] {
            XCTAssertEqual(policiesArray.count, 1)

            let firstPolicy = policiesArray[0]
            XCTAssertEqual(firstPolicy["policyId"] as? String, "valid-type")

            if let params = firstPolicy["params"] as? [String: Any],
               let types = params["types"] as? [String] {
                XCTAssertEqual(types, ["boolean"])
            } else {
                XCTFail("Failed to parse policy params")
            }
        } else {
            XCTFail("Failed to parse policies array")
        }
    }

    func testInitValueWithSpecificProperties() {
        let newCallback = AttributeInputCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.name, value: "test_attribute")
        newCallback.initValue(name: JourneyConstants.prompt, value: "Test Prompt")
        newCallback.initValue(name: JourneyConstants.required, value: false)

        XCTAssertEqual(newCallback.name, "test_attribute")
        XCTAssertEqual(newCallback.prompt, "Test Prompt")
        XCTAssertFalse(newCallback.required)
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = AttributeInputCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.name, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.prompt, value: 456) // Invalid type
        newCallback.initValue(name: JourneyConstants.required, value: "not a bool") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.required)
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = AttributeInputCallback()

        // Test that properties from parent class are also handled
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true)
        newCallback.initValue(name: JourneyConstants.policies, value: [
            "name": "test_policy",
            "policyRequirements": ["REQUIRED"]
        ])

        XCTAssertTrue(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies["name"] as? String, "test_policy")
    }

    func testRequiredPropertyVariations() {
        let testCases = [true, false]

        for requiredValue in testCases {
            let newCallback = AttributeInputCallback()
            newCallback.initValue(name: JourneyConstants.required, value: requiredValue)

            XCTAssertEqual(newCallback.required, requiredValue, "Failed for required value: \(requiredValue)")
        }
    }

    func testNamePropertyWithDifferentValues() {
        let testNames = ["", "simple_name", "complex_name_with_underscores", "name123", "UPPERCASE_NAME"]

        for testName in testNames {
            let newCallback = AttributeInputCallback()
            newCallback.initValue(name: JourneyConstants.name, value: testName)

            XCTAssertEqual(newCallback.name, testName, "Failed for name: \(testName)")
        }
    }

    func testPromptPropertyWithDifferentValues() {
        let testPrompts = ["", "Simple Prompt", "Complex Prompt with Numbers 123", "Prompt with Special Characters !@#$%"]

        for testPrompt in testPrompts {
            let newCallback = AttributeInputCallback()
            newCallback.initValue(name: JourneyConstants.prompt, value: testPrompt)

            XCTAssertEqual(newCallback.prompt, testPrompt, "Failed for prompt: \(testPrompt)")
        }
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = AttributeInputCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: 123)
        newCallback.initValue(name: "unknownProperty3", value: true)

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.required)
    }

    func testCompleteInitializationScenario() {
        let newCallback = AttributeInputCallback()

        // Initialize all properties like in a real scenario
        newCallback.initValue(name: JourneyConstants.name, value: "email_address")
        newCallback.initValue(name: JourneyConstants.prompt, value: "Email Address")
        newCallback.initValue(name: JourneyConstants.required, value: true)
        newCallback.initValue(name: JourneyConstants.validateOnly, value: false)
        newCallback.initValue(name: JourneyConstants.policies, value: [
            "name": "email_address",
            "policyRequirements": ["REQUIRED", "VALID_EMAIL_ADDRESS_FORMAT"]
        ])
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: [String]())

        // Verify all properties are set correctly
        XCTAssertEqual(newCallback.name, "email_address")
        XCTAssertEqual(newCallback.prompt, "Email Address")
        XCTAssertTrue(newCallback.required)
        XCTAssertFalse(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies["name"] as? String, "email_address")
        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }

    func testDefaultValues() {
        let newCallback = AttributeInputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.required)
        XCTAssertFalse(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies.count, 0)
        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }
}
