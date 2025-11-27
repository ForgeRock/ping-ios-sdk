//
//  NumberAttributeInputCallbackTests.swift
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

class NumberAttributeInputCallbackTests: XCTestCase {

    private var callback: NumberAttributeInputCallback!
    
    override func setUp() {
        super.setUp()
        callback = NumberAttributeInputCallback()

        let jsonString = """
        {
          "type": "NumberAttributeInputCallback",
          "output": [
            {
              "name": "name",
              "value": "custom_age"
            },
            {
              "name": "prompt",
              "value": "How old are you?"
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
                "name": "custom_age",
                "policies": [
                  {
                    "policyRequirements": [
                      "VALID_TYPE"
                    ],
                    "policyId": "valid-type",
                    "params": {
                      "types": [
                        "number"
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
              "value": 30.0
            }
          ],
          "input": [
            {
              "name": "IDToken3",
              "value": 30.0
            },
            {
              "name": "IDToken3validateOnly",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = NumberAttributeInputCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testNumberAttributeInputCallbackInitializesValueCorrectlyFromJson() {
        // Test that the number value is initialized correctly from JSON
        XCTAssertEqual(callback.value, 30.0)
    }

    func testPayloadReturnsCorrectly() {
        callback.validateOnly = true

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (value)
            if let doubleValue = inputArray[0]["value"] as? Double {
                XCTAssertEqual(doubleValue, 30.0)
            } else {
                XCTFail("Number value is not a Double or not found")
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

        // Test with modified value
        callback.value = 20.0
        let modifiedPayload = callback.payload()

        if let inputArray = modifiedPayload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Double {
            XCTAssertEqual(value, 20.0)
        } else {
            XCTFail("Modified payload structure is not as expected")
        }
    }

    func testInheritsFromAttributeInputCallback() {
        // Test that properties from AttributeInputCallback are also initialized
        XCTAssertEqual(callback.name, "custom_age")
        XCTAssertEqual(callback.prompt, "How old are you?")
        XCTAssertTrue(callback.required)

        // Test that properties from AbstractValidatedCallback are also initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)

        // Test policies structure
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements, ["VALID_TYPE"])
        } else {
            XCTFail("Failed to parse policyRequirements")
        }
    }

    func testInitValueWithDoubleValue() {
        let newCallback = NumberAttributeInputCallback()
        newCallback.initValue(name: JourneyConstants.value, value: 42.5)

        XCTAssertEqual(newCallback.value, 42.5)
    }

    func testInitValueWithIntValue() {
        let newCallback = NumberAttributeInputCallback()
        newCallback.initValue(name: JourneyConstants.value, value: 25)

        XCTAssertEqual(newCallback.value, 25.0) // Should be converted to Double
    }

    func testInitValueWithStringValue() {
        let newCallback = NumberAttributeInputCallback()

        // Test valid string numbers
        newCallback.initValue(name: JourneyConstants.value, value: "123.45")
        XCTAssertEqual(newCallback.value, 123.45)

        newCallback.initValue(name: JourneyConstants.value, value: "67")
        XCTAssertEqual(newCallback.value, 67.0)

        newCallback.initValue(name: JourneyConstants.value, value: "0")
        XCTAssertEqual(newCallback.value, 0.0)

        newCallback.initValue(name: JourneyConstants.value, value: "-15.5")
        XCTAssertEqual(newCallback.value, -15.5)
    }

    func testInitValueWithInvalidStringValue() {
        let newCallback = NumberAttributeInputCallback()

        // Test invalid string that cannot be converted to Double
        newCallback.initValue(name: JourneyConstants.value, value: "not a number")

        // Should maintain default value when conversion fails
        XCTAssertEqual(newCallback.value, 0.0)
    }

    func testInitValueWithInvalidType() {
        let newCallback = NumberAttributeInputCallback()

        // Test with completely invalid types - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.value, value: ["not", "a", "number"])
        XCTAssertEqual(newCallback.value, 0.0)

        newCallback.initValue(name: JourneyConstants.value, value: ["key": "value"])
        XCTAssertEqual(newCallback.value, 0.0)

        newCallback.initValue(name: JourneyConstants.value, value: true)
        XCTAssertEqual(newCallback.value, 0.0)
    }

    func testValueCanBeModified() {
        // Test that the value property can be changed after initialization
        XCTAssertEqual(callback.value, 30.0) // Initially 30.0 from JSON

        callback.value = 45.5
        XCTAssertEqual(callback.value, 45.5)

        callback.value = 0.0
        XCTAssertEqual(callback.value, 0.0)

        callback.value = -10.25
        XCTAssertEqual(callback.value, -10.25)
    }

    func testPayloadWithDifferentValues() {
        let testValues = [0.0, 1.0, -1.0, 123.456, 999999.99, 0.001]

        for testValue in testValues {
            callback.value = testValue
            callback.validateOnly = false

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                if let doubleValue = inputArray[0]["value"] as? Double {
                    XCTAssertEqual(doubleValue, testValue, accuracy: 0.001, "Failed for value: \(testValue)")
                } else {
                    XCTFail("Number value is not a Double for value: \(testValue)")
                }

                if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                    XCTAssertFalse(validateOnlyValue)
                } else {
                    XCTFail("ValidateOnly value is not a Bool for value: \(testValue)")
                }
            } else {
                XCTFail("Payload structure is not as expected for value: \(testValue)")
            }
        }
    }

    func testPayloadWithValidateOnlyVariations() {
        let validateOnlyTestCases = [true, false]

        for validateOnly in validateOnlyTestCases {
            callback.value = 42.0
            callback.validateOnly = validateOnly

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                XCTAssertEqual(inputArray[0]["value"] as? Double, 42.0)
                XCTAssertEqual(inputArray[1]["value"] as? Bool, validateOnly, "Failed for validateOnly: \(validateOnly)")
            } else {
                XCTFail("Payload structure is not as expected for validateOnly: \(validateOnly)")
            }
        }
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = NumberAttributeInputCallback()

        // Test that properties from parent classes are also handled
        newCallback.initValue(name: JourneyConstants.name, value: "user_weight")
        newCallback.initValue(name: JourneyConstants.prompt, value: "Enter your weight in kg")
        newCallback.initValue(name: JourneyConstants.required, value: false)
        newCallback.initValue(name: JourneyConstants.value, value: 70.5)

        XCTAssertEqual(newCallback.name, "user_weight")
        XCTAssertEqual(newCallback.prompt, "Enter your weight in kg")
        XCTAssertFalse(newCallback.required)
        XCTAssertEqual(newCallback.value, 70.5)
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic scenario
        callback.initValue(name: JourneyConstants.name, value: "employee_salary")
        callback.initValue(name: JourneyConstants.prompt, value: "Annual salary (USD)")
        callback.initValue(name: JourneyConstants.required, value: true)
        callback.initValue(name: JourneyConstants.value, value: 75000.0)
        callback.initValue(name: JourneyConstants.validateOnly, value: false)

        // Verify all properties are set correctly
        XCTAssertEqual(callback.name, "employee_salary")
        XCTAssertEqual(callback.prompt, "Annual salary (USD)")
        XCTAssertTrue(callback.required)
        XCTAssertEqual(callback.value, 75000.0)
        XCTAssertFalse(callback.validateOnly)

        // User modifies the value
        callback.value = 80000.0

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? Double, 80000.0)
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = NumberAttributeInputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.value, 0.0)
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.required)
        XCTAssertFalse(newCallback.validateOnly)
    }

    func testEdgeNumbers() {
        let newCallback = NumberAttributeInputCallback()
        let edgeNumbers = [
            Double.infinity,
            -Double.infinity,
            Double.nan,
            Double.greatestFiniteMagnitude,
            Double.leastNormalMagnitude,
            0.0,
            -0.0
        ]

        for edgeNumber in edgeNumbers {
            newCallback.initValue(name: JourneyConstants.value, value: edgeNumber)

            if edgeNumber.isNaN {
                XCTAssertTrue(newCallback.value.isNaN, "Failed for NaN value")
            } else if edgeNumber.isInfinite {
                XCTAssertTrue(newCallback.value.isInfinite, "Failed for infinite value: \(edgeNumber)")
                XCTAssertEqual(newCallback.value.sign, edgeNumber.sign, "Sign mismatch for infinite value")
            } else {
                XCTAssertEqual(newCallback.value, edgeNumber, "Failed for edge number: \(edgeNumber)")
            }
        }
    }

    func testStringToDoubleConversion() {
        let stringTestCases: [(String, Double?)] = [
            ("123", 123.0),
            ("123.456", 123.456),
            ("-42.5", -42.5),
            ("0", 0.0),
            ("0.0", 0.0),
            ("-0", 0.0),
            ("1e6", 1000000.0),
            ("1.5e-3", 0.0015),
            ("invalid", nil),
            ("", nil),
            ("123abc", nil),
            ("abc123", nil),
            ("12.34.56", nil)
        ]

        for (stringValue, expectedValue) in stringTestCases {
            let newCallback = NumberAttributeInputCallback()
            newCallback.initValue(name: JourneyConstants.value, value: stringValue)

            if let expected = expectedValue {
                XCTAssertEqual(newCallback.value, expected, accuracy: 0.0001, "Failed for string: '\(stringValue)'")
            } else {
                XCTAssertEqual(newCallback.value, 0.0, "Should use default value for invalid string: '\(stringValue)'")
            }
        }
    }

    func testIntToDoubleConversion() {
        let intTestCases = [0, 1, -1, 42, -42, 999999, Int.max, Int.min]

        for intValue in intTestCases {
            let newCallback = NumberAttributeInputCallback()
            newCallback.initValue(name: JourneyConstants.value, value: intValue)

            XCTAssertEqual(newCallback.value, Double(intValue), "Failed for int value: \(intValue)")
        }
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = NumberAttributeInputCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: 123.45)

        // Should maintain default value for known properties
        XCTAssertEqual(newCallback.value, 0.0)
    }

    func testPayloadWithNegativeNumber() {
        callback.value = -123.456
        callback.validateOnly = false

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Double {
            XCTAssertEqual(value, -123.456)
        } else {
            XCTFail("Payload structure is not as expected for negative number")
        }
    }

    func testPayloadWithZero() {
        callback.value = 0.0

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Double {
            XCTAssertEqual(value, 0.0)
        } else {
            XCTFail("Payload structure is not as expected for zero")
        }
    }

    func testPayloadWithVeryLargeNumber() {
       callback.value = 1.23456789e15

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Double {
            XCTAssertEqual(value, 1.23456789e15, accuracy: 1e10)
        } else {
            XCTFail("Payload structure is not as expected for very large number")
        }
    }
}
