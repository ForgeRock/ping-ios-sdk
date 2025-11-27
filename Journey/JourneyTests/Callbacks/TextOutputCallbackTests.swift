//
//  TextOutputCallbackTests.swift
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

class TextOutputCallbackTests: XCTestCase {

    private var callback: TextOutputCallback!
    
    override func setUp() {
        super.setUp()
        callback = TextOutputCallback()

        let jsonString = """
        {
          "type": "TextOutputCallback",
          "output": [
            {
              "name": "message",
              "value": "Test"
            },
            {
              "name": "messageType",
              "value": "0"
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = TextOutputCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.message, "Test")
        XCTAssertEqual(callback.messageType, MessageType.information)
    }

    func testPayloadReturnsSuperPayloadWhenMessageTypeIsNotUnknown() {
        let warningJsonString = """
        {
          "type": "TextOutputCallback",
          "output": [
            {
              "name": "message",
              "value": "Test"
            },
            {
              "name": "messageType",
              "value": "1"
            }
          ]
        }
        """

        if let data = warningJsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            let newCallback = TextOutputCallback()
            newCallback.json = parsed

            // Initialize callback
            if let output = parsed["output"] as? [[String: Any]] {
                for item in output {
                    if let name = item["name"] as? String,
                       let value = item["value"] {
                        newCallback.initValue(name: name, value: value)
                    }
                }
            }

            let payload = newCallback.payload()

            XCTAssertEqual(newCallback.message, "Test")
            XCTAssertEqual(newCallback.messageType, MessageType.warning)
            XCTAssertNotEqual(payload.count, 0, "Payload should not be empty when messageType is not unknown")

            // Verify payload contains the original structure
            if let type = payload["type"] as? String {
                XCTAssertEqual(type, "TextOutputCallback")
            }
        } else {
            XCTFail("Failed to parse warning JSON")
        }
    }

    func testPayloadReturnsEmptyDictionaryWhenMessageTypeIsUnknown() {
        let unknownJsonString = """
        {
          "type": "TextOutputCallback",
          "output": [
            {
              "name": "message",
              "value": "Test"
            },
            {
              "name": "messageType",
              "value": "999"
            }
          ]
        }
        """

        if let data = unknownJsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            let newCallback = TextOutputCallback()
            newCallback.json = parsed

            // Initialize callback
            if let output = parsed["output"] as? [[String: Any]] {
                for item in output {
                    if let name = item["name"] as? String,
                       let value = item["value"] {
                        newCallback.initValue(name: name, value: value)
                    }
                }
            }

            let payload = newCallback.payload()

            XCTAssertEqual(newCallback.messageType, MessageType.unknown) // Invalid value should default to unknown
            XCTAssertEqual(payload.count, 0, "Payload should be empty when messageType is unknown")
        } else {
            XCTFail("Failed to parse unknown messageType JSON")
        }
    }

    func testMessageTypeEnumMapping() {
        let messageTypeTestCases: [(String, MessageType)] = [
            ("0", .information),
            ("1", .warning),
            ("2", .error),
            ("999", .unknown), // Invalid value should map to unknown
            ("-1", .unknown)   // Negative value should map to unknown
        ]

        for (stringValue, expectedType) in messageTypeTestCases {
            let newCallback = TextOutputCallback()
            newCallback.initValue(name: JourneyConstants.messageType, value: stringValue)

            XCTAssertEqual(newCallback.messageType, expectedType, "Failed for messageType string: '\(stringValue)'")
        }
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = TextOutputCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.message, value: "Welcome to our service")
        newCallback.initValue(name: JourneyConstants.messageType, value: "0")

        XCTAssertEqual(newCallback.message, "Welcome to our service")
        XCTAssertEqual(newCallback.messageType, MessageType.information)
    }

    func testInitValueWithInvalidMessageType() {
        let newCallback = TextOutputCallback()

        // Test with invalid messageType values
        let invalidMessageTypes = ["not a number", "", "abc", "12.5"]

        for invalidType in invalidMessageTypes {
            newCallback.initValue(name: JourneyConstants.messageType, value: invalidType)

            // Should default to unknown when conversion fails
            XCTAssertEqual(newCallback.messageType, MessageType.unknown, "Should use unknown for invalid messageType: '\(invalidType)'")
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = TextOutputCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.message, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.messageType, value: 456) // Invalid type (not string)

        // Should maintain default values
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = TextOutputCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testMessageTypeScenarios() {
        let messageScenarios: [(MessageType, String, String)] = [
            (.information, "0", "Welcome! Your account has been created successfully."),
            (.warning, "1", "Warning: Your session will expire in 5 minutes."),
            (.error, "2", "Error: Invalid credentials. Please try again.")
        ]

        for (expectedType, typeString, testMessage) in messageScenarios {
            let newCallback = TextOutputCallback()
            newCallback.json = ["type": "TextOutputCallback"] // Set json so payload works

            newCallback.initValue(name: JourneyConstants.message, value: testMessage)
            newCallback.initValue(name: JourneyConstants.messageType, value: typeString)

            XCTAssertEqual(newCallback.messageType, expectedType)
            XCTAssertEqual(newCallback.message, testMessage)

            // Test payload behavior
            let payload = newCallback.payload()
            XCTAssertNotEqual(payload.count, 0, "Payload should not be empty for valid messageType")
        }
    }

    func testPayloadWithDifferentMessageTypes() {
        let testCases: [(String, Bool)] = [
            ("0", false), // information - should return json
            ("1", false), // warning - should return json
            ("2", false), // error - should return json
            ("999", true) // unknown - should return empty
        ]

        for (messageTypeString, shouldBeEmpty) in testCases {
            let newCallback = TextOutputCallback()
            newCallback.json = callback.json // Set json property

            newCallback.initValue(name: JourneyConstants.message, value: "Test message")
            newCallback.initValue(name: JourneyConstants.messageType, value: messageTypeString)

            let payload = newCallback.payload()

            if shouldBeEmpty {
                XCTAssertEqual(payload.count, 0, "Payload should be empty for messageType: \(messageTypeString)")
            } else {
                XCTAssertNotEqual(payload.count, 0, "Payload should not be empty for messageType: \(messageTypeString)")
            }
        }
    }

    func testCompleteInitializationScenario() {
        let newCallback = TextOutputCallback()
        newCallback.json = [
            "type": "TextOutputCallback",
            "output": [
                ["name": "message", "value": "Authentication successful"],
                ["name": "messageType", "value": "0"]
            ]
        ]

        // Initialize in a realistic authentication success scenario
        newCallback.initValue(name: JourneyConstants.message, value: "Authentication successful! You will be redirected shortly.")
        newCallback.initValue(name: JourneyConstants.messageType, value: "0")

        // Verify all properties are set correctly
        XCTAssertEqual(newCallback.message, "Authentication successful! You will be redirected shortly.")
        XCTAssertEqual(newCallback.messageType, MessageType.information)

        // Test payload
        let payload = newCallback.payload()
        XCTAssertNotEqual(payload.count, 0, "Payload should contain original JSON structure")
    }

    func testDefaultValues() {
        let newCallback = TextOutputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testLongMessages() {
        let newCallback = TextOutputCallback()
        let longMessage = """
        This is a very long informational message that might be displayed to users during the authentication process. It could contain detailed instructions, explanations of what's happening, or important information that users need to understand before proceeding with their authentication journey. Such messages might span multiple lines and contain various types of information including contact details, troubleshooting steps, or links to additional resources.
        """

        newCallback.initValue(name: JourneyConstants.message, value: longMessage)
        newCallback.initValue(name: JourneyConstants.messageType, value: "0")

        XCTAssertEqual(newCallback.message, longMessage)
        XCTAssertEqual(newCallback.messageType, MessageType.information)
    }

    func testInternationalMessages() {
        let newCallback = TextOutputCallback()

        // Test messages in different languages
        let internationalMessages = [
            "Bienvenido a nuestro servicio", // Spanish
            "Bienvenue dans notre service", // French
            "Willkommen bei unserem Service", // German
            "サービスへようこそ", // Japanese
            "مرحبا بكم في خدمتنا", // Arabic
            "Добро пожаловать в наш сервис" // Russian
        ]

        for internationalMessage in internationalMessages {
            newCallback.initValue(name: JourneyConstants.message, value: internationalMessage)
            XCTAssertEqual(newCallback.message, internationalMessage, "Failed for international message")
        }
    }

    func testMessagesWithSpecialCharacters() {
        let newCallback = TextOutputCallback()
        let specialMessages = [
            "Message with !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "HTML content: <strong>Bold text</strong>",
            "JSON structure: {\"status\": \"success\", \"code\": 200}",
            "URLs: Visit https://example.com for more info",
            "Email: Contact support@company.com",
            "Unicode symbols: ✓ ✗ ⚠ ℹ ★",
            "Math expressions: E = mc²",
            "Emojis: ✅ Authentication successful! 🎉",
            "Code snippet: if (user.isValid()) { return true; }"
        ]

        for specialMessage in specialMessages {
            newCallback.initValue(name: JourneyConstants.message, value: specialMessage)
            XCTAssertEqual(newCallback.message, specialMessage, "Failed for special message")
        }
    }

    func testEmptyMessage() {
        let newCallback = TextOutputCallback()
        newCallback.initValue(name: JourneyConstants.message, value: "")
        newCallback.initValue(name: JourneyConstants.messageType, value: "0")

        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.information)
    }

    func testMessageWithWhitespace() {
        let newCallback = TextOutputCallback()

        // Test messages with various whitespace scenarios
        let whitespaceMessages = [
            " ",
            "  ",
            " Message with leading space",
            "Message with trailing space ",
            "Message  with  double  spaces",
            "\tMessage\twith\ttabs",
            "\nMessage\nwith\nnewlines",
            "Multi-line message:\n\nLine 1\nLine 2\nLine 3"
        ]

        for whitespaceMessage in whitespaceMessages {
            newCallback.initValue(name: JourneyConstants.message, value: whitespaceMessage)
            XCTAssertEqual(newCallback.message, whitespaceMessage, "Failed to preserve whitespace for message")
        }
    }

    func testAuthenticationFlowMessages() {
        // Test various authentication flow messages
        let authFlowMessages: [(MessageType, String, String)] = [
            (.information, "0", "Please enter your username and password."),
            (.information, "0", "Authentication successful! Redirecting..."),
            (.warning, "1", "Your password will expire in 7 days."),
            (.warning, "1", "Multiple failed login attempts detected."),
            (.error, "2", "Invalid username or password."),
            (.error, "2", "Account has been temporarily locked."),
            (.error, "2", "Network error occurred. Please try again.")
        ]

        for (expectedType, typeString, message) in authFlowMessages {
            let newCallback = TextOutputCallback()
            newCallback.json = ["type": "TextOutputCallback"] // Set json for payload

            newCallback.initValue(name: JourneyConstants.message, value: message)
            newCallback.initValue(name: JourneyConstants.messageType, value: typeString)

            XCTAssertEqual(newCallback.messageType, expectedType)
            XCTAssertEqual(newCallback.message, message)

            // Test payload behavior
            let payload = newCallback.payload()
            XCTAssertNotEqual(payload.count, 0, "Payload should not be empty for valid messageType")
        }
    }

    func testPayloadStructurePreservation() {
        // Test that payload preserves the original JSON structure
        let payload = callback.payload()

        XCTAssertNotNil(payload)
        XCTAssertNotEqual(payload.count, 0)

        // Verify the structure is preserved
        if let output = payload["output"] as? [[String: Any]] {
            XCTAssertEqual(output.count, 2)

            // Find message output
            let messageOutput = output.first { ($0["name"] as? String) == "message" }
            XCTAssertEqual(messageOutput?["value"] as? String, "Test")

            // Find messageType output
            let messageTypeOutput = output.first { ($0["name"] as? String) == "messageType" }
            XCTAssertEqual(messageTypeOutput?["value"] as? String, "0")
        } else {
            XCTFail("Payload does not preserve original output structure")
        }
    }

    func testMessageTypeConstants() {
        // Test that the MessageType enum values match expected constants
        XCTAssertEqual(MessageType.information.rawValue, 0)
        XCTAssertEqual(MessageType.warning.rawValue, 1)
        XCTAssertEqual(MessageType.error.rawValue, 2)
        XCTAssertEqual(MessageType.unknown.rawValue, -1)
    }

    func testStringToMessageTypeConversion() {
        let newCallback = TextOutputCallback()

        // Test the string to messageType conversion logic
        let conversionTestCases: [(String, MessageType)] = [
            ("0", .information),
            ("1", .warning),
            ("2", .error),
            ("-1", .unknown),
            ("3", .unknown), // Invalid value
            ("invalid", .unknown), // Non-numeric string
            ("", .unknown) // Empty string
        ]

        for (stringValue, expectedType) in conversionTestCases {
            newCallback.initValue(name: JourneyConstants.messageType, value: stringValue)
            XCTAssertEqual(newCallback.messageType, expectedType, "Failed conversion for: '\(stringValue)'")
        }
    }

    func testPayloadBehaviorWithUnknownMessageType() {
        let newCallback = TextOutputCallback()

        // Set messageType to unknown and verify empty payload
        newCallback.initValue(name: JourneyConstants.messageType, value: "invalid")

        let payload = newCallback.payload()
        XCTAssertEqual(payload.count, 0, "Payload should be empty for unknown messageType")
    }

    func testReadOnlyProperties() {
        // Test that message and messageType properties are read-only after initialization
        XCTAssertEqual(callback.message, "Test")
        XCTAssertEqual(callback.messageType, MessageType.information)

        // Properties should be private(set), so they can't be modified directly
        // This test verifies they maintain their values
        XCTAssertEqual(callback.message, "Test")
        XCTAssertEqual(callback.messageType, MessageType.information)
    }

    func testNonStringMessageTypeHandling() {
        let newCallback = TextOutputCallback()

        // Test with non-string messageType (should be rejected)
        newCallback.initValue(name: JourneyConstants.messageType, value: 1) // Int instead of String

        // Should maintain default value since it expects string
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }
}
