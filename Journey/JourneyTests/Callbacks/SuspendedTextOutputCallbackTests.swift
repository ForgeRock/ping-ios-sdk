//
//  SuspendedTextOutputCallbackTests.swift
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

class SuspendedTextOutputCallbackTests: XCTestCase {

    private var callback: SuspendedTextOutputCallback!
    private var jsonObject: [String: Any]!

    override func setUp() {
        super.setUp()
        callback = SuspendedTextOutputCallback()

        let jsonString = """
        {
          "type": "SuspendedTextOutputCallback",
          "output": [
            {
              "name": "message",
              "value": "An email has been sent to the address you entered. Click the link in that email to proceed."
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
             callback = SuspendedTextOutputCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(
            callback.message,
            "An email has been sent to the address you entered. Click the link in that email to proceed."
        )
        XCTAssertEqual(callback.messageType, MessageType.information)
    }

    func testPayloadReturnsCorrectly() {
        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected format
        if let type = payload["type"] as? String {
            XCTAssertEqual(type, "SuspendedTextOutputCallback")
        } else {
            XCTFail("Payload should contain type information")
        }

        if let output = payload["output"] as? [[String: Any]],
           output.count >= 2 {

            // Find message output
            let messageOutput = output.first { ($0["name"] as? String) == "message" }
            XCTAssertEqual(
                messageOutput?["value"] as? String,
                "An email has been sent to the address you entered. Click the link in that email to proceed."
            )

            // Find messageType output
            let messageTypeOutput = output.first { ($0["name"] as? String) == "messageType" }
            XCTAssertNotNil(messageTypeOutput?["value"])
        } else {
            XCTFail("Payload output structure is not as expected")
        }
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = SuspendedTextOutputCallback()

        // Test initializing individual properties inherited from TextOutputCallback
        newCallback.initValue(name: JourneyConstants.message, value: "Authentication suspended. Please check your email.")
        newCallback.initValue(name: JourneyConstants.messageType, value: "1") // Warning

        XCTAssertEqual(newCallback.message, "Authentication suspended. Please check your email.")
        XCTAssertEqual(newCallback.messageType, MessageType.warning)
    }

    func testSuspensionMessages() {
        let newCallback = SuspendedTextOutputCallback()

        // Test various suspension-related messages
        let suspensionMessages = [
            "Your authentication has been suspended. Please check your email for instructions to resume.",
            "We've sent a verification link to your email. Click it to continue.",
            "Authentication paused. A resume link has been sent to your registered email address.",
            "Please check your email and click the provided link to complete authentication.",
            "Session suspended for security. Email verification required to proceed.",
            "Multi-factor authentication required. Check your email for the next step.",
            "Your login attempt has been temporarily suspended. Please follow the email instructions to continue."
        ]

        for suspensionMessage in suspensionMessages {
            newCallback.initValue(name: JourneyConstants.message, value: suspensionMessage)
            XCTAssertEqual(newCallback.message, suspensionMessage, "Failed for suspension message test")
        }
    }

    func testMessageTypes() {
        let newCallback = SuspendedTextOutputCallback()

        // Test different message types for suspension scenarios
        let messageTypeTestCases: [(String, MessageType, String)] = [
            ("0", .information, "Standard suspension notification"),
            ("1", .warning, "Security-related suspension warning"),
            ("2", .error, "Error-based suspension message")
        ]

        for (rawValue, expectedType, description) in messageTypeTestCases {
            newCallback.initValue(name: JourneyConstants.messageType, value: rawValue)
            XCTAssertEqual(newCallback.messageType, expectedType, "Failed for \(description)")
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = SuspendedTextOutputCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.message, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.messageType, value: "invalid") // Invalid type

        // Should maintain default values from TextOutputCallback
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = SuspendedTextOutputCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty", value: "some value")

        // Should maintain default values
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testCompleteInitializationScenario() {
       // Initialize in a realistic email suspension scenario
        callback.initValue(name: JourneyConstants.message, value: "Authentication suspended. We've sent a secure link to user@example.com. Please check your email and click the link to continue within 30 minutes.")
        callback.initValue(name: JourneyConstants.messageType, value: 0) // Information

        // Verify all properties are set correctly
        XCTAssertEqual(callback.message, "Authentication suspended. We've sent a secure link to user@example.com. Please check your email and click the link to continue within 30 minutes.")
        XCTAssertEqual(callback.messageType, MessageType.information)

        // Test payload preserves the suspension information
        let payload = callback.payload()
        XCTAssertNotNil(payload)

        if let type = payload["type"] as? String {
            XCTAssertEqual(type, "SuspendedTextOutputCallback")
        } else {
            XCTFail("Payload should preserve callback type")
        }
    }

    func testDefaultValues() {
        let newCallback = SuspendedTextOutputCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.message, "")
        XCTAssertEqual(newCallback.messageType, MessageType.unknown)
    }

    func testInternationalSuspensionMessages() {
        let newCallback = SuspendedTextOutputCallback()

        // Test suspension messages in different languages
        let internationalMessages = [
            "La autenticación ha sido suspendida. Revise su correo electrónico.", // Spanish
            "L'authentification a été suspendue. Vérifiez votre e-mail.", // French
            "Die Authentifizierung wurde ausgesetzt. Überprüfen Sie Ihre E-Mail.", // German
            "認証が一時停止されました。メールを確認してください。", // Japanese
            "تم تعليق المصادقة. يرجى التحقق من بريدك الإلكتروني.", // Arabic
            "Аутентификация приостановлена. Проверьте вашу электронную почту." // Russian
        ]

        for internationalMessage in internationalMessages {
            newCallback.initValue(name: JourneyConstants.message, value: internationalMessage)
            XCTAssertEqual(newCallback.message, internationalMessage, "Failed for international message")
        }
    }

    func testSuspensionMessageWithEmojis() {
        let newCallback = SuspendedTextOutputCallback()
        let emojiMessage = "🔒 Authentication suspended 📧 Check your email for the resume link ⏰ Link expires in 30 minutes"

        newCallback.initValue(name: JourneyConstants.message, value: emojiMessage)

        XCTAssertEqual(newCallback.message, emojiMessage)
    }

    func testPayloadPreservesOriginalStructure() {
        let payload = callback.payload()

        // Since SuspendedTextOutputCallback inherits from TextOutputCallback without overriding payload(),
        // it should preserve the original JSON structure
        XCTAssertNotNil(payload)

        // Verify the structure is preserved
        if let output = payload["output"] as? [[String: Any]] {
            XCTAssertEqual(output.count, 2)

            // Verify original message is preserved
            let messageOutput = output.first { ($0["name"] as? String) == "message" }
            XCTAssertEqual(
                messageOutput?["value"] as? String,
                "An email has been sent to the address you entered. Click the link in that email to proceed."
            )

            // Verify messageType is preserved
            let messageTypeOutput = output.first { ($0["name"] as? String) == "messageType" }
            XCTAssertEqual(messageTypeOutput?["value"] as? String, "0")
        } else {
            XCTFail("Payload does not preserve original output structure")
        }
    }
}
