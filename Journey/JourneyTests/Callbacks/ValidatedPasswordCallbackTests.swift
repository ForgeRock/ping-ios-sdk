//
//  ValidatedPasswordCallbackTests.swift
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

class ValidatedPasswordCallbackTests: XCTestCase {

    private var callback: ValidatedPasswordCallback!

    override func setUp() {
        super.setUp()
        callback = ValidatedPasswordCallback()

        let jsonString = """
        {
          "type": "ValidatedCreatePasswordCallback",
          "output": [
            {
              "name": "echoOn",
              "value": false
            },
            {
              "name": "policies",
              "value": {
                "policyRequirements": [
                  "VALID_TYPE"
                ],
                "fallbackPolicies": null,
                "name": "password",
                "policies": [
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
              "name": "prompt",
              "value": "Password"
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": ""
            },
            {
              "name": "IDToken1validateOnly",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = ValidatedPasswordCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "Password")
        XCTAssertFalse(callback.echoOn)
        XCTAssertEqual(callback.password, "")
    }

    func testPayloadReturnsCorrectly() {
        callback.password = "password"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (password)
            if let passwordValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(passwordValue, "password")
            } else {
                XCTFail("Password value is not a String or not found")
            }

            // Check second input (validateOnly)
            if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                XCTAssertFalse(validateOnlyValue) // Default value
            } else {
                XCTFail("ValidateOnly value is not a Bool or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInheritsFromAbstractValidatedCallback() {
        // Test that properties from AbstractValidatedCallback are also initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)

        // Test policies structure for password validation
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements, ["VALID_TYPE"])
        } else {
            XCTFail("Failed to parse policyRequirements")
        }

        if let policiesArray = callback.policies["policies"] as? [[String: Any]] {
            XCTAssertEqual(policiesArray.count, 1)

            let firstPolicy = policiesArray[0]
            XCTAssertEqual(firstPolicy["policyId"] as? String, "valid-type")

            if let params = firstPolicy["params"] as? [String: Any],
               let types = params["types"] as? [String] {
                XCTAssertEqual(types, ["string"])
            } else {
                XCTFail("Failed to parse policy params")
            }
        } else {
            XCTFail("Failed to parse policies array")
        }
    }

    func testEchoOnProperty() {
        let testCases = [true, false]

        for echoValue in testCases {
            let newCallback = ValidatedPasswordCallback()
            newCallback.initValue(name: JourneyConstants.echoOn, value: echoValue)

            XCTAssertEqual(newCallback.echoOn, echoValue, "Failed for echoOn value: \(echoValue)")
        }
    }

    func testPasswordCanBeModified() {
        // Test that the password property can be changed after initialization
        XCTAssertEqual(callback.password, "") // Initially empty

        callback.password = "testPassword123"
        XCTAssertEqual(callback.password, "testPassword123")

        callback.password = "newP@ssw0rd!"
        XCTAssertEqual(callback.password, "newP@ssw0rd!")

        callback.password = ""
        XCTAssertEqual(callback.password, "")
    }

    func testPayloadWithValidateOnly() {
        callback.password = "securePassword123"
        callback.validateOnly = true

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check password value
            if let passwordValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(passwordValue, "securePassword123")
            } else {
                XCTFail("Password value is not a String or not found")
            }

            // Check validateOnly value
            if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                XCTAssertTrue(validateOnlyValue)
            } else {
                XCTFail("ValidateOnly value is not a Bool or not found")
            }
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = ValidatedPasswordCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.prompt, value: "Create a secure password")
        newCallback.initValue(name: JourneyConstants.echoOn, value: true)
        newCallback.initValue(name: JourneyConstants.validateOnly, value: false)

        XCTAssertEqual(newCallback.prompt, "Create a secure password")
        XCTAssertTrue(newCallback.echoOn)
        XCTAssertFalse(newCallback.validateOnly)
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = ValidatedPasswordCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.echoOn, value: "not a bool") // Invalid type
        newCallback.initValue(name: JourneyConstants.validateOnly, value: "not a bool") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.echoOn)
        XCTAssertFalse(newCallback.validateOnly)
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = ValidatedPasswordCallback()

        // Test that properties from AbstractValidatedCallback are also handled
        newCallback.initValue(name: JourneyConstants.policies, value: [
            "name": "test_password",
            "policyRequirements": ["REQUIRED", "MIN_LENGTH"]
        ])
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: [
            "{ \"params\": { \"minLength\": 8 }, \"policyRequirement\": \"MIN_LENGTH\" }"
        ])

        XCTAssertEqual(newCallback.policies["name"] as? String, "test_password")
        XCTAssertEqual(newCallback.failedPolicies.count, 1)
        XCTAssertEqual(newCallback.failedPolicies[0].policyRequirement, "MIN_LENGTH")
    }

    func testPayloadWithDifferentPasswords() {
        let passwordTestCases = [
            "",
            "simple",
            "password123",
            "Str0ng!P@ssw0rd",
            "Very_Long_Password_With_Numbers_123_And_Special_Characters!@#$%",
            "pássword123", // Accented characters
            "пароль123", // Cyrillic
            "密码123", // Chinese
            "🔒SecureP@ss123🔑", // Emojis
            "Multi\nline\npassword",
            "Pass word with spaces",
            "JSON-like{\"pwd\":\"secret\"}"
        ]

        for testPassword in passwordTestCases {
            callback.password = testPassword
            callback.validateOnly = false

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                if let passwordValue = inputArray[0]["value"] as? String {
                    XCTAssertEqual(passwordValue, testPassword, "Failed for password: '\(testPassword)'")
                } else {
                    XCTFail("Password value is not a String for password: '\(testPassword)'")
                }

                if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                    XCTAssertFalse(validateOnlyValue)
                } else {
                    XCTFail("ValidateOnly value is not a Bool for password: '\(testPassword)'")
                }
            } else {
                XCTFail("Payload structure is not as expected for password: '\(testPassword)'")
            }
        }
    }

    func testPayloadWithValidateOnlyVariations() {
        let validateOnlyTestCases = [true, false]

        for validateOnly in validateOnlyTestCases {
            callback.password = "TestP@ssw0rd123"
            callback.validateOnly = validateOnly

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                XCTAssertEqual(inputArray[0]["value"] as? String, "TestP@ssw0rd123")
                XCTAssertEqual(inputArray[1]["value"] as? Bool, validateOnly, "Failed for validateOnly: \(validateOnly)")
            } else {
                XCTFail("Payload structure is not as expected for validateOnly: \(validateOnly)")
            }
        }
    }

    func testEchoOnScenarios() {
        // Test different echoOn scenarios for password visibility
        let echoScenarios: [(Bool, String)] = [
            (false, "Hidden password input (default)"),
            (true, "Visible password input (for confirmation fields)")
        ]

        for (echoValue, description) in echoScenarios {
            let newCallback = ValidatedPasswordCallback()
            newCallback.initValue(name: JourneyConstants.echoOn, value: echoValue)

            XCTAssertEqual(newCallback.echoOn, echoValue, "Failed for \(description)")
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic password creation scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Create a strong password")
        callback.initValue(name: JourneyConstants.echoOn, value: false)
        callback.initValue(name: JourneyConstants.validateOnly, value: false)
        callback.initValue(name: JourneyConstants.policies, value: [
            "name": "password",
            "policyRequirements": ["REQUIRED", "MIN_LENGTH", "AT_LEAST_X_CAPITAL_LETTERS", "AT_LEAST_X_NUMBERS"]
        ])

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Create a strong password")
        XCTAssertFalse(callback.echoOn)
        XCTAssertFalse(callback.validateOnly)
        XCTAssertEqual(callback.password, "") // Default value

        // User enters a secure password
        callback.password = "SecureP@ssw0rd123!"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "SecureP@ssw0rd123!")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = ValidatedPasswordCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.echoOn)
        XCTAssertEqual(newCallback.password, "")
        XCTAssertFalse(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies.count, 0)
        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }

    func testPasswordValidationScenarios() {
        // Test various password validation scenarios
        let validationScenarios: [(String, [String], String)] = [
            ("Create password", ["REQUIRED", "MIN_LENGTH"], "P@ssw0rd123"),
            ("Confirm password", ["REQUIRED", "MATCH_REGEXP"], "MatchingPassword!"),
            ("New password", ["MIN_LENGTH", "AT_LEAST_X_CAPITAL_LETTERS", "AT_LEAST_X_NUMBERS"], "NewSecure123"),
            ("Recovery password", ["REQUIRED", "VALID_TYPE"], "RecoveryPass456")
        ]

        for (promptText, requirements, userPassword) in validationScenarios {
            let newCallback = ValidatedPasswordCallback()

            newCallback.initValue(name: JourneyConstants.prompt, value: promptText)
            newCallback.initValue(name: JourneyConstants.policies, value: [
                "policyRequirements": requirements
            ])

            XCTAssertEqual(newCallback.prompt, promptText)

            // User enters password
            newCallback.password = userPassword

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, userPassword, "Failed for validation scenario: \(promptText)")
            }
        }
    }

    func testPasswordSecurityLevels() {
        let passwordSecurityTests = [
            ("weak", "Weak password"),
            ("password123", "Medium password with numbers"),
            ("Password123", "Medium password with capitals and numbers"),
            ("P@ssw0rd123", "Strong password with special characters"),
            ("VeryStr0ng!P@ssw0rd#2024", "Very strong password"),
            ("CorrectHorseBatteryStaple2024!", "Passphrase style password"),
            ("🔒UltraSecure!P@ss123🔑", "Password with emojis")
        ]

        for (password, description) in passwordSecurityTests {
            let newCallback = ValidatedPasswordCallback()
            newCallback.password = password

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, password, "Failed for \(description)")
            }
        }
    }

    func testEchoOnForPasswordConfirmation() {
        // Test echoOn=true scenario (typically used for password confirmation fields)
        let newCallback = ValidatedPasswordCallback()
        newCallback.initValue(name: JourneyConstants.prompt, value: "Confirm your password")
        newCallback.initValue(name: JourneyConstants.echoOn, value: true)

        XCTAssertEqual(newCallback.prompt, "Confirm your password")
        XCTAssertTrue(newCallback.echoOn)

        newCallback.password = "MatchingPassword123!"

        let payload = newCallback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "MatchingPassword123!")
        }
    }

    func testPasswordWithWhitespace() {
        let newCallback = ValidatedPasswordCallback()

        // Test passwords with whitespace (some systems allow this)
        let whitespacePasswords = [
            " password ",
            " leadingSpace",
            "trailingSpace ",
            "pass word",
            "pass  word", // Double space
            "\tpassword\t", // Tabs
            "multi\nline\npassword"
        ]

        for testPassword in whitespacePasswords {
            newCallback.password = testPassword
            let payload = newCallback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testPassword, "Failed to preserve whitespace for password")
            }
        }
    }

    func testPasswordLengthVariations() {
        let newCallback = ValidatedPasswordCallback()

        // Test passwords of various lengths
        let lengthTestCases = [
            ("", 0),
            ("a", 1),
            ("short", 5),
            ("mediumLength123", 15),
            ("VeryLongPasswordThatExceedsTypicalRequirements123!", 50),
            (String(repeating: "Long", count: 25), 100) // 100 characters
        ]

        for (testPassword, expectedLength) in lengthTestCases {
            newCallback.password = testPassword

            XCTAssertEqual(newCallback.password.count, expectedLength, "Length mismatch for password of length \(expectedLength)")

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value.count, expectedLength)
                XCTAssertEqual(value, testPassword)
            }
        }
    }

    func testPasswordCreationFlow() {
        let newCallback = ValidatedPasswordCallback()

        // Simulate a complete password creation flow
        newCallback.initValue(name: JourneyConstants.prompt, value: "Choose a secure password")
        newCallback.initValue(name: JourneyConstants.echoOn, value: false)
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true) // Validate first

        // User tries a weak password
        newCallback.password = "weak"

        let weakPayload = newCallback.payload()
        if let inputArray = weakPayload["input"] as? [[String: Any]] {
            XCTAssertEqual(inputArray[0]["value"] as? String, "weak")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, true) // validateOnly
        }

        // User improves password
        newCallback.password = "StrongP@ssw0rd123!"
        newCallback.validateOnly = false // Now ready to submit

        let strongPayload = newCallback.payload()
        if let inputArray = strongPayload["input"] as? [[String: Any]] {
            XCTAssertEqual(inputArray[0]["value"] as? String, "StrongP@ssw0rd123!")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false) // Final submission
        }
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = ValidatedPasswordCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.echoOn)
        XCTAssertEqual(newCallback.password, "")
    }

    func testPasswordWithSpecialCharacters() {
        let newCallback = ValidatedPasswordCallback()
        let specialPasswords = [
            "P@ssw0rd!",
            "Pass#Word$123",
            "Complex&Password^With%Many*Special(Characters)",
            "HTML<script>alert('test')</script>Pass",
            "JSON{\"pass\":\"word\"}123",
            "URL:https://example.com/path?param=value",
            "Math:α+β=γ&password123"
        ]

        for specialPassword in specialPasswords {
            newCallback.password = specialPassword

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, specialPassword, "Failed for special password")
            }
        }
    }
}
