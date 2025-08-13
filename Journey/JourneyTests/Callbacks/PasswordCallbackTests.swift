//
//  PasswordCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class PasswordCallbackTests: XCTestCase {

    private var callback: PasswordCallback!

    override func setUp() {
        super.setUp()
        callback = PasswordCallback()

        let jsonString = """
        {
          "output": [
            {
              "name": "prompt",
              "value": "Password"
            }
          ],
          "input": [
            {
              "name": "IDToken2",
              "value": ""
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = PasswordCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesPromptWhenJsonElementContainsPrompt() {
        XCTAssertEqual(callback.prompt, "Password")
    }

    func testPayloadReturnsPasswordCorrectly() {
        callback.password = "password"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "password")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithEmptyPassword() {
        // Don't set password (should remain empty string)

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPasswordCanBeModified() {
        // Test that the password property can be changed after initialization
        XCTAssertEqual(callback.password, "") // Initially empty

        callback.password = "secret123"
        XCTAssertEqual(callback.password, "secret123")

        callback.password = "newPassword456"
        XCTAssertEqual(callback.password, "newPassword456")

        callback.password = ""
        XCTAssertEqual(callback.password, "")
    }

    func testInitValueWithPrompt() {
        let newCallback = PasswordCallback()
        newCallback.initValue(name: JourneyConstants.prompt, value: "Enter your password")

        XCTAssertEqual(newCallback.prompt, "Enter your password")
    }

    func testInitValueWithInvalidType() {
        let newCallback = PasswordCallback()

        // Test with invalid type - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type

        // Should maintain default value
        XCTAssertEqual(newCallback.prompt, "")
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = PasswordCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.password, "")
    }

    func testPayloadWithDifferentPasswords() {
        let testPasswords = [
            "",
            "a",
            "simple",
            "password123",
            "P@ssw0rd!",
            "Very_Long_Password_With_123_Numbers_And_Special_Characters!@#$%",
            "pássword", // Accented characters
            "パスワード", // Japanese characters
            "كلمة المرور", // Arabic characters
            "🔒🔑password123🔒", // Emojis
            "pass word", // Spaces
            "pass\tword", // Tabs
            "pass\nword" // Newlines
        ]

        for testPassword in testPasswords {
            callback.password = testPassword
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testPassword, "Failed for password: '\(testPassword)'")
            } else {
                XCTFail("Payload structure is not as expected for password: '\(testPassword)'")
            }
        }
    }

    func testPromptWithDifferentValues() {
        let promptTestCases = [
            "",
            "Password",
            "Enter your password",
            "Please provide your secure password",
            "What is your password?",
            "Mot de passe (French)",
            "Password 🔒",
            "Enter the password you created during registration",
            "Re-enter your password to confirm"
        ]

        for testPrompt in promptTestCases {
            let newCallback = PasswordCallback()
            newCallback.initValue(name: JourneyConstants.prompt, value: testPrompt)

            XCTAssertEqual(newCallback.prompt, testPrompt, "Failed for prompt: '\(testPrompt)'")
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize in a realistic login scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Enter your password")

        // Verify prompt is set correctly
        XCTAssertEqual(callback.prompt, "Enter your password")
        XCTAssertEqual(callback.password, "") // Default value

        // User enters their password
        callback.password = "MySecureP@ssw0rd123"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "MySecureP@ssw0rd123")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = PasswordCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.password, "")
    }

    func testPasswordSecurityScenarios() {
        let securityTestCases = [
            "weak",
            "strongP@ssw0rd123",
            "ComplexP@ssw0rd!WithManyCharacters123456",
            "😀🔒🔑SecureEmoji123!",
            "CorrectHorseBatteryStaple", // XKCD reference
            "ThisIsAVeryLongPassphraseInsteadOfATraditionalPassword2024!"
        ]

        for securePassword in securityTestCases {
            callback.password = securePassword

            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, securePassword, "Failed for secure password test")
            } else {
                XCTFail("Payload structure is not as expected for secure password")
            }
        }
    }

    func testPasswordWithWhitespace() {
        // Test passwords with various whitespace scenarios
        let whitespaceTestCases = [
            " ",
            "  ",
            " password ",
            " password123 ",
            "pass word", // Space in middle
            "pass  word", // Double space
            "\tpassword\t", // Tabs
            "\npassword\n", // Newlines
            "password\r\n" // Windows line endings
        ]

        for testPassword in whitespaceTestCases {
            callback.password = testPassword
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testPassword, "Failed to preserve whitespace for password: '\(testPassword)'")
            } else {
                XCTFail("Payload structure is not as expected for whitespace test")
            }
        }
    }

    func testPasswordChangeFlow() {
        // Simulate a password change flow
        callback.initValue(name: JourneyConstants.prompt, value: "Enter new password")

        // User tries different passwords
        callback.password = "weak"
        XCTAssertEqual(callback.password, "weak")

        callback.password = "StrongerP@ssw0rd123"
        XCTAssertEqual(callback.password, "StrongerP@ssw0rd123")

        // Final password selection
        callback.password = "FinalSecureP@ssw0rd2024!"

        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "FinalSecureP@ssw0rd2024!")
        } else {
            XCTFail("Payload structure is not as expected for password change flow")
        }
    }

    func testEmptyPasswordValue() {
        callback.password = ""

        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "")
        } else {
            XCTFail("Payload structure is not as expected for empty password")
        }
    }
}
