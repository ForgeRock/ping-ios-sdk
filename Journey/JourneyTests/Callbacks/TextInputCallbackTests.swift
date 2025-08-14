//
//  TextInputCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class TextInputCallbackTests: XCTestCase {

    private var callback: TextInputCallback!
    
    override func setUp() {
        super.setUp()
        callback = TextInputCallback()

        let jsonString = """
        {
          "type": "TextInputCallback",
          "output": [
            {
              "name": "prompt",
              "value": "One Time Pin"
            },
            {
              "name": "defaultText",
              "value": "default"
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": ""
            }
          ],
          "_id": 0
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = TextInputCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.prompt, "One Time Pin")
        XCTAssertEqual(callback.defaultText, "default")
        XCTAssertEqual(callback.text, "default") // Should be set to defaultText initially
    }

    func testPayloadReturnsCorrectly() {
        callback.text = "test"

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "test")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithDefaultText() {
        // Don't modify text - should remain as defaultText

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "default")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testTextCanBeModified() {
        // Test that the text property can be changed after initialization
        XCTAssertEqual(callback.text, "default") // Initially set to defaultText

        callback.text = "123456"
        XCTAssertEqual(callback.text, "123456")

        callback.text = "modified input"
        XCTAssertEqual(callback.text, "modified input")

        callback.text = ""
        XCTAssertEqual(callback.text, "")
    }

    func testDefaultTextSetsInitialTextValue() {
        let newCallback = TextInputCallback()

        // Test that setting defaultText also sets text
        newCallback.initValue(name: JourneyConstants.defaultText, value: "initial value")

        XCTAssertEqual(newCallback.defaultText, "initial value")
        XCTAssertEqual(newCallback.text, "initial value") // Should be set automatically
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = TextInputCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.prompt, value: "Enter verification code")
        newCallback.initValue(name: JourneyConstants.defaultText, value: "000000")

        XCTAssertEqual(newCallback.prompt, "Enter verification code")
        XCTAssertEqual(newCallback.defaultText, "000000")
        XCTAssertEqual(newCallback.text, "000000") // Should match defaultText
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = TextInputCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.defaultText, value: 456) // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.defaultText, "")
        XCTAssertEqual(newCallback.text, "")
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = TextInputCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.defaultText, "")
        XCTAssertEqual(newCallback.text, "")
    }

    func testPayloadWithDifferentTexts() {
        let testTexts = [
            "",
            "1",
            "123456",
            "OTP123",
            "verification code",
            "User Input Text",
            "Text with special chars !@#$%",
            "International: café, naïve, résumé",
            "Emojis: 🔐🔑✅",
            "Numbers and letters: abc123xyz",
            "Multi\nline\ntext",
            "Very long text input that could potentially be entered by a user who wants to provide detailed information in a text field"
        ]

        for testText in testTexts {
            callback.text = testText
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testText, "Failed for text: '\(testText)'")
            } else {
                XCTFail("Payload structure is not as expected for text: '\(testText)'")
            }
        }
    }

    func testOTPScenarios() {
        // Test One Time Pin scenarios (based on the test data prompt)
        let otpTestCases: [(String, String, String)] = [
            ("Enter 6-digit code", "000000", "123456"),
            ("SMS verification code", "------", "789012"),
            ("Email verification pin", "", "4567"),
            ("Authenticator code", "000000", "890123"),
            ("Security code", "123456", "654321")
        ]

        for (promptText, defaultValue, userInput) in otpTestCases {
            let newCallback = TextInputCallback()

            newCallback.initValue(name: JourneyConstants.prompt, value: promptText)
            newCallback.initValue(name: JourneyConstants.defaultText, value: defaultValue)

            XCTAssertEqual(newCallback.prompt, promptText)
            XCTAssertEqual(newCallback.defaultText, defaultValue)
            XCTAssertEqual(newCallback.text, defaultValue) // Initially set to default

            // User enters their code
            newCallback.text = userInput

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, userInput, "Failed for OTP scenario: \(promptText)")
            }
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize in a realistic OTP verification scenario
        callback.initValue(name: JourneyConstants.prompt, value: "Enter the 6-digit verification code sent to your phone")
        callback.initValue(name: JourneyConstants.defaultText, value: "")

        // Verify all properties are set correctly
        XCTAssertEqual(callback.prompt, "Enter the 6-digit verification code sent to your phone")
        XCTAssertEqual(callback.defaultText, "")
        XCTAssertEqual(callback.text, "") // Should match defaultText

        // User enters verification code
        callback.text = "987654"

        // Test payload with user input
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "987654")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = TextInputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.defaultText, "")
        XCTAssertEqual(newCallback.text, "")
    }

    func testEmptyDefaultText() {
        let newCallback = TextInputCallback()
        newCallback.initValue(name: JourneyConstants.defaultText, value: "")

        XCTAssertEqual(newCallback.defaultText, "")
        XCTAssertEqual(newCallback.text, "") // Should also be empty
    }

    func testDifferentDefaultTexts() {
        let defaultTextTestCases = [
            "",
            "placeholder",
            "default",
            "Enter text here",
            "Pre-filled value",
            "123456",
            "user@example.com",
            "Default with special chars !@#"
        ]

        for defaultText in defaultTextTestCases {
            let newCallback = TextInputCallback()
            newCallback.initValue(name: JourneyConstants.defaultText, value: defaultText)

            XCTAssertEqual(newCallback.defaultText, defaultText, "Failed for defaultText: '\(defaultText)'")
            XCTAssertEqual(newCallback.text, defaultText, "Text should match defaultText for: '\(defaultText)'")
        }
    }

    func testPromptVariations() {
        let newCallback = TextInputCallback()

        let promptTestCases = [
            "",
            "Text input",
            "One Time Pin",
            "Enter verification code",
            "Please provide additional information",
            "What is your favorite color?",
            "Security question answer",
            "Enter your response",
            "Verification code (check your email)",
            "Additional comments (optional)"
        ]

        for prompt in promptTestCases {
            newCallback.initValue(name: JourneyConstants.prompt, value: prompt)
            XCTAssertEqual(newCallback.prompt, prompt, "Failed for prompt: '\(prompt)'")
        }
    }

    func testTextInputWithWhitespace() {
        // Test text with various whitespace scenarios
        let whitespaceTestCases = [
            " ",
            "  ",
            " text ",
            " leading space",
            "trailing space ",
            "text  with  spaces",
            "\ttext\twith\ttabs",
            "\ntext\nwith\nnewlines"
        ]

        for testText in whitespaceTestCases {
            callback.text = testText
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testText, "Failed to preserve whitespace for: '\(testText)'")
            } else {
                XCTFail("Payload structure is not as expected for whitespace test")
            }
        }
    }

    func testUserOverridesDefaultText() {
        // Test that user can override the default text
        XCTAssertEqual(callback.text, "default") // Initially set to defaultText

        callback.text = "user input"
        XCTAssertEqual(callback.text, "user input")
        XCTAssertEqual(callback.defaultText, "default") // defaultText should remain unchanged

        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "user input")
        }
    }

    func testTextInputWithSpecialCharacters() {
        let specialCharacterTexts = [
            "Text with !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "HTML <div>content</div>",
            "JSON {\"key\": \"value\"}",
            "Unicode: ñáéíóú",
            "Emojis: 📱💻🔐",
            "Math: α + β = γ",
            "Currency: $100.50 €85.25",
            "Code: function() { return true; }"
        ]

        for specialText in specialCharacterTexts {
            callback.text = specialText

            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, specialText, "Failed for special text: '\(specialText)'")
            } else {
                XCTFail("Payload structure is not as expected for special text")
            }
        }
    }

    func testInternationalTextInput() {
        let newCallback = TextInputCallback()

        // Test text input in different languages
        let internationalTexts = [
            "English text",
            "Texto en español",
            "Texte en français",
            "Deutscher Text",
            "日本語のテキスト",
            "النص العربي",
            "Русский текст",
            "中文文本",
            "한국어 텍스트"
        ]

        for internationalText in internationalTexts {
            newCallback.text = internationalText

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, internationalText, "Failed for international text")
            }
        }
    }

    func testTextLengthVariations() {
        // Test various text lengths
        let lengthTestCases = [
            ("", 0),
            ("a", 1),
            ("123456", 6),
            ("Short text", 10),
            ("Medium length text input", 24),
            (String(repeating: "Long ", count: 50), 250) // 250 characters
        ]

        for (testText, expectedLength) in lengthTestCases {
            callback.text = testText

            XCTAssertEqual(callback.text.count, expectedLength, "Length mismatch for text of length \(expectedLength)")

            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value.count, expectedLength)
                XCTAssertEqual(value, testText)
            }
        }
    }

    func testVerificationCodeScenarios() {
        // Test various verification code scenarios
        let verificationScenarios: [(String, String, String)] = [
            ("SMS verification code", "000000", "123456"),
            ("Email verification code", "ABCDEF", "XYZ789"),
            ("TOTP from authenticator app", "", "654321"),
            ("Backup recovery code", "XXXX-XXXX", "ABCD-1234"),
            ("Phone verification PIN", "0000", "9876")
        ]

        for (promptText, defaultValue, userCode) in verificationScenarios {
            let newCallback = TextInputCallback()

            newCallback.initValue(name: JourneyConstants.prompt, value: promptText)
            newCallback.initValue(name: JourneyConstants.defaultText, value: defaultValue)

            XCTAssertEqual(newCallback.text, defaultValue) // Initially set to default

            // User enters their verification code
            newCallback.text = userCode

            let payload = newCallback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, userCode, "Failed for verification scenario: \(promptText)")
            }
        }
    }

    func testEmptyTextInput() {
        let newCallback = TextInputCallback()
        newCallback.initValue(name: JourneyConstants.prompt, value: "Optional comment")
        newCallback.initValue(name: JourneyConstants.defaultText, value: "")

        // User leaves it empty
        newCallback.text = ""

        let payload = newCallback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "")
        }
    }

    func testDefaultTextDoesNotAffectPrompt() {
        let newCallback = TextInputCallback()

        // Ensure that setting defaultText doesn't affect prompt
        newCallback.initValue(name: JourneyConstants.prompt, value: "Original prompt")
        newCallback.initValue(name: JourneyConstants.defaultText, value: "Some default")

        XCTAssertEqual(newCallback.prompt, "Original prompt")
        XCTAssertEqual(newCallback.defaultText, "Some default")
        XCTAssertEqual(newCallback.text, "Some default")

        // Change text - should not affect prompt or defaultText
        newCallback.text = "Changed text"

        XCTAssertEqual(newCallback.prompt, "Original prompt")
        XCTAssertEqual(newCallback.defaultText, "Some default")
        XCTAssertEqual(newCallback.text, "Changed text")
    }
}
