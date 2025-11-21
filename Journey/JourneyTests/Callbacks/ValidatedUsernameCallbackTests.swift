//
//  ValidatedUsernameCallbackTests.swift
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

class ValidatedUsernameCallbackTests: XCTestCase {

    private var callback: ValidatedUsernameCallback!
    
    override func setUp() {
        super.setUp()
        callback = ValidatedUsernameCallback()

        let jsonString = """
        {
          "type": "ValidatedCreateUsernameCallback",
          "output": [
            {
              "name": "policies",
              "value": {
                "policyRequirements": [
                  "REQUIRED",
                  "VALID_TYPE",
                  "VALID_USERNAME",
                  "CANNOT_CONTAIN_CHARACTERS",
                  "MIN_LENGTH",
                  "MAX_LENGTH"
                ],
                "fallbackPolicies": null,
                "name": "userName",
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
                    "policyId": "valid-username",
                    "policyRequirements": [
                      "VALID_USERNAME"
                    ]
                  },
                  {
                    "params": {
                      "forbiddenChars": [
                        "/"
                      ]
                    },
                    "policyId": "cannot-contain-characters",
                    "policyRequirements": [
                      "CANNOT_CONTAIN_CHARACTERS"
                    ]
                  },
                  {
                    "params": {
                      "minLength": 1
                    },
                    "policyId": "minimum-length",
                    "policyRequirements": [
                      "MIN_LENGTH"
                    ]
                  },
                  {
                    "params": {
                      "maxLength": 255
                    },
                    "policyId": "maximum-length",
                    "policyRequirements": [
                      "MAX_LENGTH"
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
              "name": "prompt",
              "value": "Username"
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
             callback = ValidatedUsernameCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "Username")
        XCTAssertEqual(callback.username, "")
    }

    func testPayloadReturnsCorrectly() {
        callback.username = "testUser"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check first input (username)
            if let usernameValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(usernameValue, "testUser")
            } else {
                XCTFail("Username value is not a String or not found")
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
        // Test that properties from AbstractValidatedCallback are properly initialized
        XCTAssertNotNil(callback.policies)
        XCTAssertEqual(callback.failedPolicies.count, 0)
        XCTAssertFalse(callback.validateOnly)

        // Test the complex username validation policies structure
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements, [
                "REQUIRED",
                "VALID_TYPE",
                "VALID_USERNAME",
                "CANNOT_CONTAIN_CHARACTERS",
                "MIN_LENGTH",
                "MAX_LENGTH"
            ])
        } else {
            XCTFail("Failed to parse policyRequirements")
        }

        if let policiesArray = callback.policies["policies"] as? [[String: Any]] {
            XCTAssertEqual(policiesArray.count, 6)

            // Test specific policies
            let requiredPolicy = policiesArray[0]
            XCTAssertEqual(requiredPolicy["policyId"] as? String, "required")

            let lengthPolicy = policiesArray[4] // minimum-length policy
            XCTAssertEqual(lengthPolicy["policyId"] as? String, "minimum-length")
            if let params = lengthPolicy["params"] as? [String: Any] {
                XCTAssertEqual(params["minLength"] as? Int, 1)
            }

            let maxLengthPolicy = policiesArray[5] // maximum-length policy
            XCTAssertEqual(maxLengthPolicy["policyId"] as? String, "maximum-length")
            if let params = maxLengthPolicy["params"] as? [String: Any] {
                XCTAssertEqual(params["maxLength"] as? Int, 255)
            }
        } else {
            XCTFail("Failed to parse policies array")
        }
    }

    func testUsernameCanBeModified() {
        // Test that the username property can be changed after initialization
        XCTAssertEqual(callback.username, "") // Initially empty

        callback.username = "john_doe"
        XCTAssertEqual(callback.username, "john_doe")

        callback.username = "admin123"
        XCTAssertEqual(callback.username, "admin123")

        callback.username = ""
        XCTAssertEqual(callback.username, "")
    }

    func testPayloadWithValidateOnly() {
        callback.username = "validationUser"
        callback.validateOnly = true

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {

            // Check username value
            if let usernameValue = inputArray[0]["value"] as? String {
                XCTAssertEqual(usernameValue, "validationUser")
            } else {
                XCTFail("Username value is not a String or not found")
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

    func testPayloadWithDifferentUsernames() {
        let usernameTestCases = [
            "",
            "a",
            "user",
            "john_doe",
            "user123",
            "admin_user",
            "test.user",
            "user-name",
            "VeryLongUsernameWithManyCharacters123",
            "user@domain", // Email-style username
            "user+tag",
            "simple",
            "CamelCaseUsername",
            "UPPERCASE_USER",
            "mixed_Case_123"
        ]

        for testUsername in usernameTestCases {
            callback.username = testUsername
            callback.validateOnly = false

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                if let usernameValue = inputArray[0]["value"] as? String {
                    XCTAssertEqual(usernameValue, testUsername, "Failed for username: '\(testUsername)'")
                } else {
                    XCTFail("Username value is not a String for username: '\(testUsername)'")
                }

                if let validateOnlyValue = inputArray[1]["value"] as? Bool {
                    XCTAssertFalse(validateOnlyValue)
                } else {
                    XCTFail("ValidateOnly value is not a Bool for username: '\(testUsername)'")
                }
            } else {
                XCTFail("Payload structure is not as expected for username: '\(testUsername)'")
            }
        }
    }

    func testPayloadWithValidateOnlyVariations() {
        let validateOnlyTestCases = [true, false]

        for validateOnly in validateOnlyTestCases {
            callback.username = "testuser123"
            callback.validateOnly = validateOnly

            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               inputArray.count >= 2 {

                XCTAssertEqual(inputArray[0]["value"] as? String, "testuser123")
                XCTAssertEqual(inputArray[1]["value"] as? Bool, validateOnly, "Failed for validateOnly: \(validateOnly)")
            } else {
                XCTFail("Payload structure is not as expected for validateOnly: \(validateOnly)")
            }
        }
    }

    func testInitValueCallsSuperMethod() {
        let newCallback = ValidatedUsernameCallback()

        // Test that properties from AbstractValidatedCallback are handled
        newCallback.initValue(name: JourneyConstants.prompt, value: "Choose username")
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true)
        newCallback.initValue(name: JourneyConstants.policies, value: [
            "name": "userName",
            "policyRequirements": ["REQUIRED", "VALID_USERNAME"]
        ])

        XCTAssertEqual(newCallback.prompt, "Choose username")
        XCTAssertTrue(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies["name"] as? String, "userName")
    }

    func testUsernameValidationPolicies() {
        // Test the specific username validation policies from the JSON
        let policies = callback.policies

        // Test policy requirements
        if let policyRequirements = policies["policyRequirements"] as? [String] {
            XCTAssertTrue(policyRequirements.contains("REQUIRED"))
            XCTAssertTrue(policyRequirements.contains("VALID_USERNAME"))
            XCTAssertTrue(policyRequirements.contains("CANNOT_CONTAIN_CHARACTERS"))
            XCTAssertTrue(policyRequirements.contains("MIN_LENGTH"))
            XCTAssertTrue(policyRequirements.contains("MAX_LENGTH"))
        } else {
            XCTFail("Failed to parse policyRequirements")
        }

        // Test forbidden characters policy
        if let policiesArray = policies["policies"] as? [[String: Any]] {
            let forbiddenCharsPolicy = policiesArray.first {
                ($0["policyId"] as? String) == "cannot-contain-characters"
            }

            if let params = forbiddenCharsPolicy?["params"] as? [String: Any],
               let forbiddenChars = params["forbiddenChars"] as? [String] {
                XCTAssertEqual(forbiddenChars, ["/"])
            } else {
                XCTFail("Failed to parse forbidden characters policy")
            }
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic username creation scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Choose a unique username")
        callback.initValue(name: JourneyConstants.validateOnly, value: false)
        callback.initValue(name: JourneyConstants.policies, value: [
            "name": "userName",
            "policyRequirements": ["REQUIRED", "VALID_USERNAME", "MIN_LENGTH", "MAX_LENGTH"]
        ])

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Choose a unique username")
        XCTAssertFalse(callback.validateOnly)
        XCTAssertEqual(callback.username, "") // Default value

        // User enters their username
        callback.username = "john_doe_2024"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           inputArray.count >= 2 {
            XCTAssertEqual(inputArray[0]["value"] as? String, "john_doe_2024")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = ValidatedUsernameCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.username, "")
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertFalse(newCallback.validateOnly)
        XCTAssertEqual(newCallback.policies.count, 0)
        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }

    func testUsernameValidationFlow() {
        let newCallback = ValidatedUsernameCallback()

        // Simulate a username validation flow
        newCallback.initValue(name: JourneyConstants.prompt, value: "Username")
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true) // Start with validation

        // User tries a username that violates policies
        newCallback.username = "user/name" // Contains forbidden character "/"

        let validationPayload = newCallback.payload()
        if let inputArray = validationPayload["input"] as? [[String: Any]] {
            XCTAssertEqual(inputArray[0]["value"] as? String, "user/name")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, true) // validateOnly
        }

        // User corrects the username
        newCallback.username = "valid_username"
        newCallback.validateOnly = false // Ready to submit

        let submissionPayload = newCallback.payload()
        if let inputArray = submissionPayload["input"] as? [[String: Any]] {
            XCTAssertEqual(inputArray[0]["value"] as? String, "valid_username")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false) // Final submission
        }
    }

    func testUsernameFormats() {
        let usernameFormatTests: [(String, String)] = [
            ("email_style", "user@domain.com"),
            ("underscore_separated", "first_last_123"),
            ("hyphen_separated", "user-name-123"),
            ("dot_separated", "user.name.123"),
            ("camelCase", "userName123"),
            ("lowercase", "username"),
            ("uppercase", "USERNAME"),
            ("mixed_case", "UserName123"),
            ("numeric_suffix", "user123456"),
            ("short", "usr"),
            ("long", "very_long_username_with_many_characters_123")
        ]

        for (description, username) in usernameFormatTests {
            let newCallback = ValidatedUsernameCallback()
            newCallback.username = username

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, username, "Failed for \(description): '\(username)'")
            }
        }
    }

    func testUsernamesWithForbiddenCharacters() {
        // Test usernames that would violate the CANNOT_CONTAIN_CHARACTERS policy
        let forbiddenUsernameTests = [
            "user/name", // Contains "/"
            "test/user/123",
            "admin/root",
            "/username",
            "username/"
        ]

        for forbiddenUsername in forbiddenUsernameTests {
            let newCallback = ValidatedUsernameCallback()
            newCallback.username = forbiddenUsername

            // The callback should still accept and return the value
            // (validation enforcement is typically handled by the server)
            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, forbiddenUsername, "Should accept forbidden username for client-side handling")
            }
        }
    }

    func testUsernameWithSpecialCharacters() {
        let newCallback = ValidatedUsernameCallback()

        // Test usernames with various special characters (some may be allowed, some not)
        let specialCharacterUsernames = [
            "user_name",
            "user-name",
            "user.name",
            "user+tag",
            "user@domain",
            "user123",
            "123user",
            "user#123",
            "user$money",
            "user%test",
            "user&co"
        ]

        for specialUsername in specialCharacterUsernames {
            newCallback.username = specialUsername

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, specialUsername, "Failed for special username: '\(specialUsername)'")
            }
        }
    }

    func testUsernameRegistrationFlow() {
        let newCallback = ValidatedUsernameCallback()

        // Initialize for user registration
        newCallback.initValue(name: JourneyConstants.prompt, value: "Create your username")

        // User tries different usernames during registration
        let registrationAttempts = [
            ("user", "Too short"),
            ("username_with_forbidden/char", "Contains forbidden character"),
            ("perfect_username_123", "Valid username")
        ]

        for (attemptedUsername, description) in registrationAttempts {
            newCallback.username = attemptedUsername
            newCallback.validateOnly = true // Validate each attempt

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]] {
                XCTAssertEqual(inputArray[0]["value"] as? String, attemptedUsername, "Failed for \(description)")
                XCTAssertEqual(inputArray[1]["value"] as? Bool, true, "Should be validating for \(description)")
            }
        }

        // Final submission with valid username
        newCallback.username = "perfect_username_123"
        newCallback.validateOnly = false

        let finalPayload = newCallback.payload()
        if let inputArray = finalPayload["input"] as? [[String: Any]] {
            XCTAssertEqual(inputArray[0]["value"] as? String, "perfect_username_123")
            XCTAssertEqual(inputArray[1]["value"] as? Bool, false) // Final submission
        }
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = ValidatedUsernameCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.username, "")
        XCTAssertEqual(newCallback.prompt, "")
    }

    func testInternationalUsernames() {
        let newCallback = ValidatedUsernameCallback()

        // Test usernames with international characters
        let internationalUsernames = [
            "usuário123", // Portuguese
            "utilisateur_été", // French
            "benutzer_ä", // German
            "用户123", // Chinese
            "ユーザー123", // Japanese
            "пользователь123" // Russian
        ]

        for internationalUsername in internationalUsernames {
            newCallback.username = internationalUsername

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, internationalUsername, "Failed for international username")
            }
        }
    }

    func testUsernameLengthBoundaries() {
            let newCallback = ValidatedUsernameCallback()

            // Test usernames at length boundaries based on policies (min: 1, max: 255)
            let lengthBoundaryTests = [
                ("", 0, "Empty username"),
                ("a", 1, "Minimum length username"),
                ("user123", 7, "Short username"),
                ("medium_length_username_123", 26, "Medium username"),
                (String(repeating: "a", count: 50), 50, "Long username"),
                (String(repeating: "long_user_", count: 25) + "123", 253, "Very long username near limit"),
                (String(repeating: "x", count: 255), 255, "Maximum length username")
            ]

            for (testUsername, expectedLength, description) in lengthBoundaryTests {
                newCallback.username = testUsername

                XCTAssertEqual(newCallback.username.count, expectedLength, "Length mismatch for \(description)")

                let payload = newCallback.payload()
                if let inputArray = payload["input"] as? [[String: Any]],
                   let firstInput = inputArray.first,
                   let value = firstInput["value"] as? String {
                    XCTAssertEqual(value.count, expectedLength, "Payload length mismatch for \(description)")
                    XCTAssertEqual(value, testUsername)
                }
            }
        }
    }
