//
//  StringAttributeInputCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class StringAttributeInputCallbackTests: XCTestCase {

    private var callback: StringAttributeInputCallback!
    
    override func setUp() {
        super.setUp()
        callback = StringAttributeInputCallback()

        let jsonString = """
        {
          "type": "StringAttributeInputCallback",
          "output": [
            {
              "name": "name",
              "value": "mail"
            },
            {
              "name": "prompt",
              "value": "Email Address"
            },
            {
              "name": "required",
              "value": true
            },
            {
              "name": "policies",
              "value": {
                "policyRequirements": [
                  "REQUIRED",
                  "VALID_TYPE",
                  "VALID_EMAIL_ADDRESS_FORMAT"
                ],
                "fallbackPolicies": null,
                "name": "mail",
                "policies": [
                  {
                    "policyRequirements": [
                      "REQUIRED"
                    ],
                    "policyId": "required"
                  },
                  {
                    "policyRequirements": [
                      "VALID_TYPE"
                    ],
                    "policyId": "valid-type",
                    "params": {
                      "types": [
                        "string"
                      ]
                    }
                  },
                  {
                    "policyId": "valid-email-address-format",
                    "policyRequirements": [
                      "VALID_EMAIL_ADDRESS_FORMAT"
                    ]
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
              "value": "original text"
            }
          ],
          "input": [
            {
              "name": "IDToken2",
              "value": "original text"
            },
            {
              "name": "IDToken2validateOnly",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = StringAttributeInputCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testStringAttributeInputCallbackInitializesValueCorrectlyFromJson() {
        // Test that the string value is initialized correctly from JSON
        XCTAssertEqual(callback.value, "original text")
    }

    func testPayloadReturnsCorrectly() {
        callback.validateOnly = true

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (value)
            if let stringValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(stringValue, "original text")
            } else {
                XCTFail("String value is not a String or not found")
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
        callback.value = "new text"
        let modifiedPayload = callback.payload()

        if let inputArray = modifiedPayload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "new text")
        } else {
            XCTFail("Modified payload structure is not as expected")
        }
    }

    func testInheritsFromAttributeInputCallback() {
        // Test that properties from AttributeInputCallback are also initialized
        XCTAssertEqual(callback.name, "mail")
        XCTAssertEqual(callback.prompt, "Email Address")
        XCTAssertTrue(callback.required)

        // Test that properties from AbstractValidatedCallback are also initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)

        // Test policies structure for email validation
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements, ["REQUIRED", "VALID_TYPE", "VALID_EMAIL_ADDRESS_FORMAT"])
        } else {
            XCTFail("Failed to parse policyRequirements")
        }
    }

    func testInitValueWithStringValue() {
        let newCallback = StringAttributeInputCallback()
        newCallback.initValue(name: JourneyConstants.value, value: "test string")

        XCTAssertEqual(newCallback.value, "test string")
    }

    func testInitValueWithInvalidType() {
        let newCallback = StringAttributeInputCallback()

        // Test with invalid type - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.value, value: 123) // Invalid type

        // Should maintain default value
        XCTAssertEqual(newCallback.value, "")
    }

    func testValueCanBeModified() {
        // Test that the value property can be changed after initialization
        XCTAssertEqual(callback.value, "original text") // Initially "original text" from JSON

        callback.value = "updated text"
        XCTAssertEqual(callback.value, "updated text")

        callback.value = ""
        XCTAssertEqual(callback.value, "")

        callback.value = "final text"
        XCTAssertEqual(callback.value, "final text")
    }

    func testPayloadWithDifferentValues() {
        let testValues = [
            "",
            "a",
            "simple text",
            "user@example.com",
            "Complex String With 123 Numbers And Special Characters!@#$%",
            "String with émojis 🎉😀",
            "Internationał chäracters àáâãäåæçèéêë",
            "日本語テキスト", // Japanese
            "العربية", // Arabic
            "Русский текст", // Russian
            "Multi\nline\nstring",
            "String\twith\ttabs",
            "String with \"quotes\" and 'apostrophes'",
            "JSON-like {\"key\": \"value\"}",
            "Very long string that could potentially be entered by a user who wants to provide a detailed description or explanation that spans multiple sentences and contains various types of information."
        ]

        for testValue in testValues {
            callback.value = testValue
            callback.validateOnly = false

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                if let stringValue = inputArray[0]["value"] as? String {
                    XCTAssertEqual(stringValue, testValue, "Failed for value: '\(testValue)'")
                } else {
                    XCTFail("String value is not a String for value: '\(testValue)'")
                }

                if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                    XCTAssertFalse(validateOnlyValue)
                } else {
                    XCTFail("ValidateOnly value is not a Bool for value: '\(testValue)'")
                }
            } else {
                XCTFail("Payload structure is not as expected for value: '\(testValue)'")
            }
        }
    }

    func testPayloadWithValidateOnlyVariations() {
        let validateOnlyTestCases = [true, false]

        for validateOnly in validateOnlyTestCases {
            callback.value = "test@example.com"
            callback.validateOnly = validateOnly

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                XCTAssertEqual(inputArray[0]["value"] as? String, "test@example.com")
                XCTAssertEqual(inputArray[1]["value"] as? Bool, validateOnly, "Failed for validateOnly: \(validateOnly)")
            } else {
                XCTFail("Payload structure is not as expected for validateOnly: \(validateOnly)")
            }
        }
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = StringAttributeInputCallback()

        // Test that properties from parent classes are also handled
        newCallback.initValue(name: JourneyConstants.name, value: "user_bio")
        newCallback.initValue(name: JourneyConstants.prompt, value: "Tell us about yourself")
        newCallback.initValue(name: JourneyConstants.required, value: false)
        newCallback.initValue(name: JourneyConstants.value, value: "I love coding and technology")

        XCTAssertEqual(newCallback.name, "user_bio")
        XCTAssertEqual(newCallback.prompt, "Tell us about yourself")
        XCTAssertFalse(newCallback.required)
        XCTAssertEqual(newCallback.value, "I love coding and technology")
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic email collection scenario
        callback.initValue(name: JourneyConstants.name, value: "email_address")
        callback.initValue(name: JourneyConstants.prompt, value: "Enter your email address")
        callback.initValue(name: JourneyConstants.required, value: true)
        callback.initValue(name: JourneyConstants.value, value: "")
        callback.initValue(name: JourneyConstants.validateOnly, value: false)

        // Verify all properties are set correctly
        XCTAssertEqual(callback.name, "email_address")
        XCTAssertEqual(callback.prompt, "Enter your email address")
        XCTAssertTrue(callback.required)
        XCTAssertEqual(callback.value, "")
        XCTAssertFalse(callback.validateOnly)

        // User enters their email
        callback.value = "user@company.com"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "user@company.com")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = StringAttributeInputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.value, "")
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.required)
        XCTAssertFalse(newCallback.validateOnly)
    }

    func testStringWithWhitespace() {
        // Test strings with various whitespace scenarios
        let whitespaceTestCases = [
            " ",
            "  ",
            " text ",
            " leading space",
            "trailing space ",
            "text  with  double  spaces",
            "\ttext\twith\ttabs",
            "\ntext\nwith\nnewlines",
            "\r\ntext\r\nwith\r\nwindows\r\nlineendings"
        ]

        for testString in whitespaceTestCases {
            callback.value = testString
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testString, "Failed to preserve whitespace for: '\(testString)'")
            } else {
                XCTFail("Payload structure is not as expected for whitespace test")
            }
        }
    }

    func testEmailValidationScenario() {
        // Test a complete email validation scenario using the initialized callback
        XCTAssertEqual(callback.name, "mail")
        XCTAssertEqual(callback.prompt, "Email Address")
        XCTAssertTrue(callback.required)

        // Test with various email formats
        let emailTestCases = [
            "user@example.com",
            "test.email+tag@domain.co.uk",
            "user123@test-domain.org",
            "firstname.lastname@company.com",
            "user+tag@subdomain.domain.com"
        ]

        for email in emailTestCases {
            callback.value = email
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, email, "Failed for email: \(email)")
            } else {
                XCTFail("Payload structure is not as expected for email: \(email)")
            }
        }
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = StringAttributeInputCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some string")

        // Should maintain default value for known properties
        XCTAssertEqual(newCallback.value, "")
    }

    func testStringWithSpecialCharacters() {
        let specialCharacters = [
            "String with !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "HTML <div>content</div>",
            "JSON {\"key\": \"value\", \"number\": 123}",
            "SQL-like text: SELECT * FROM users WHERE id = 1;",
            "Unicode symbols: ™®©℗℠",
            "Math symbols: ∑∏∆∇∂∫",
            "Currency: $€£¥₹₽",
            "Arrows: ←↑→↓↔↕",
            "Emoji mix: 🚀💻📱⚡🔥"
        ]

        for specialString in specialCharacters {
            callback.value = specialString

            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, specialString, "Failed for special string: '\(specialString)'")
            } else {
                XCTFail("Payload structure is not as expected for special string")
            }
        }
    }

    func testStringLengthVariations() {
        // Test strings of various lengths
        let lengthTestCases = [
            ("", 0),
            ("a", 1),
            ("short", 5),
            ("medium length string", 20),
            (String(repeating: "a", count: 100), 100),
            (String(repeating: "Long text ", count: 50), 500) // 500 characters
        ]

        for (testString, expectedLength) in lengthTestCases {
            callback.value = testString

            XCTAssertEqual(callback.value.count, expectedLength, "Length mismatch for string of length \(expectedLength)")

            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value.count, expectedLength, "Payload length mismatch for string of length \(expectedLength)")
                XCTAssertEqual(value, testString)
            } else {
                XCTFail("Payload structure is not as expected for length test")
            }
        }
    }

    func testDifferentStringAttributeTypes() {
        // Test various string attribute types beyond email
        let attributeScenarios: [(String, String, String)] = [
            ("username", "Choose a username", "john_doe123"),
            ("first_name", "First Name", "John"),
            ("last_name", "Last Name", "Doe"),
            ("phone_number", "Phone Number", "+1-555-123-4567"),
            ("address", "Street Address", "123 Main St, Apt 4B"),
            ("bio", "Tell us about yourself", "I'm a software developer who loves creating innovative solutions."),
            ("company", "Company Name", "Tech Solutions Inc."),
            ("job_title", "Job Title", "Senior Software Engineer")
        ]

        for (attributeName, promptText, sampleValue) in attributeScenarios {
            let newCallback = StringAttributeInputCallback()

            newCallback.initValue(name: JourneyConstants.name, value: attributeName)
            newCallback.initValue(name: JourneyConstants.prompt, value: promptText)
            newCallback.initValue(name: JourneyConstants.value, value: sampleValue)

            XCTAssertEqual(newCallback.name, attributeName)
            XCTAssertEqual(newCallback.prompt, promptText)
            XCTAssertEqual(newCallback.value, sampleValue)
        }
    }
}
