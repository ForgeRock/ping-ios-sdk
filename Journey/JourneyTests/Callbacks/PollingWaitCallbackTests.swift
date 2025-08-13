//
//  PollingWaitCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class PollingWaitCallbackTests: XCTestCase {

    private var callback: PollingWaitCallback!
    
    override func setUp() {
        super.setUp()
        callback = PollingWaitCallback()

        let jsonString = """
        {
          "type": "PollingWaitCallback",
          "output": [
            {
              "name": "waitTime",
              "value": "8000"
            },
            {
              "name": "message",
              "value": "Waiting"
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = PollingWaitCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.waitTime, 8000)
        XCTAssertEqual(callback.message, "Waiting")
    }

    func testPayloadReturnsCorrectly() {
        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Since PollingWaitCallback doesn't override payload(), it should return the original json
        // Check that the payload contains the type
        if let type = payload["type"] as? String {
            XCTAssertEqual(type, "PollingWaitCallback")
        } else {
            XCTFail("Payload should contain type information")
        }
    }

    func testInitValueWithWaitTimeString() {
        let newCallback = PollingWaitCallback()

        // Test with string wait time values
        let waitTimeTestCases = [
            ("0", 0),
            ("1000", 1000),
            ("5000", 5000),
            ("30000", 30000),
            ("60000", 60000),
            ("300000", 300000)
        ]

        for (stringValue, expectedInt) in waitTimeTestCases {
            newCallback.initValue(name: JourneyConstants.waitTime, value: stringValue)
            XCTAssertEqual(newCallback.waitTime, expectedInt, "Failed for waitTime string: '\(stringValue)'")
        }
    }

    func testInitValueWithInvalidWaitTimeString() {
        let newCallback = PollingWaitCallback()

        // Test with invalid string values that cannot be converted to Int
        let invalidWaitTimes = ["not a number", "", "abc", "12.5", "1000ms"]

        for invalidWaitTime in invalidWaitTimes {
            newCallback.initValue(name: JourneyConstants.waitTime, value: invalidWaitTime)

            // Should maintain default value when conversion fails
            XCTAssertEqual(newCallback.waitTime, 0, "Should use default value for invalid waitTime: '\(invalidWaitTime)'")
        }
    }

    func testInitValueWithMessage() {
        let newCallback = PollingWaitCallback()

        let messageTestCases = [
            "",
            "Please wait",
            "Processing your request...",
            "Authenticating with external service",
            "Waiting for approval",
            "Please wait while we verify your information",
            "Attente en cours... (French)",
            "処理中です... (Japanese)",
            "Please wait ⏳"
        ]

        for testMessage in messageTestCases {
            newCallback.initValue(name: JourneyConstants.message, value: testMessage)
            XCTAssertEqual(newCallback.message, testMessage, "Failed for message: '\(testMessage)'")
        }
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = PollingWaitCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.waitTime, value: 123) // Int instead of String
        newCallback.initValue(name: JourneyConstants.message, value: 456) // Int instead of String

        // Should maintain default values
        XCTAssertEqual(newCallback.waitTime, 0)
        XCTAssertEqual(newCallback.message, "")
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = PollingWaitCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: 123)

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.waitTime, 0)
        XCTAssertEqual(newCallback.message, "")
    }

    func testWaitTimeConversionEdgeCases() {
        let newCallback = PollingWaitCallback()

        // Test edge cases for string to int conversion
        let edgeCases: [(String, Int)] = [
            ("0", 0),
            ("1", 1),
            ("999999", 999999),
            (String(Int.max), Int.max)
        ]

        for (stringValue, expectedValue) in edgeCases {
            newCallback.initValue(name: JourneyConstants.waitTime, value: stringValue)
            XCTAssertEqual(newCallback.waitTime, expectedValue, "Failed for edge case: '\(stringValue)'")
        }
    }

    func testCompleteInitializationScenario() {
        let newCallback = PollingWaitCallback()

        // Initialize in a realistic polling scenario
        newCallback.initValue(name: JourneyConstants.waitTime, value: "15000") // 15 seconds
        newCallback.initValue(name: JourneyConstants.message, value: "Please wait while we process your authentication request...")

        // Verify all properties are set correctly
        XCTAssertEqual(newCallback.waitTime, 15000)
        XCTAssertEqual(newCallback.message, "Please wait while we process your authentication request...")

        // Test payload (should return original JSON structure)
        let payload = newCallback.payload()
        XCTAssertNotNil(payload)
    }

    func testDefaultValues() {
        let newCallback = PollingWaitCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.waitTime, 0)
        XCTAssertEqual(newCallback.message, "")
    }

    func testRealisticWaitTimes() {
        let newCallback = PollingWaitCallback()

        // Test realistic wait time scenarios
        let realisticWaitTimes: [(String, Int, String)] = [
            ("1000", 1000, "1 second wait"),
            ("5000", 5000, "5 second wait"),
            ("10000", 10000, "10 second wait"),
            ("30000", 30000, "30 second wait"),
            ("60000", 60000, "1 minute wait"),
            ("120000", 120000, "2 minute wait"),
            ("300000", 300000, "5 minute wait")
        ]

        for (waitTimeString, expectedWaitTime, description) in realisticWaitTimes {
            newCallback.initValue(name: JourneyConstants.waitTime, value: waitTimeString)
            newCallback.initValue(name: JourneyConstants.message, value: "Processing - \(description)")

            XCTAssertEqual(newCallback.waitTime, expectedWaitTime, "Failed for \(description)")
            XCTAssertEqual(newCallback.message, "Processing - \(description)")
        }
    }

    func testLongMessages() {
        let newCallback = PollingWaitCallback()
        let longMessage = "Please wait while we authenticate your credentials with our secure partner services. This process may take up to several minutes depending on network conditions and the complexity of the verification required. Thank you for your patience."

        newCallback.initValue(name: JourneyConstants.message, value: longMessage)

        XCTAssertEqual(newCallback.message, longMessage)
    }

    func testZeroWaitTime() {
        let newCallback = PollingWaitCallback()
        newCallback.initValue(name: JourneyConstants.waitTime, value: "0")

        XCTAssertEqual(newCallback.waitTime, 0)
    }

    func testPayloadPreservesOriginalStructure() {
        let payload = callback.payload()

        // Since PollingWaitCallback doesn't override payload(), it should return the original json
        XCTAssertNotNil(payload)

        // Verify the structure is preserved
        if let output = payload["output"] as? [[String: Any]] {
            XCTAssertEqual(output.count, 2)

            // Find waitTime output
            let waitTimeOutput = output.first { ($0["name"] as? String) == "waitTime" }
            XCTAssertEqual(waitTimeOutput?["value"] as? String, "8000")

            // Find message output
            let messageOutput = output.first { ($0["name"] as? String) == "message" }
            XCTAssertEqual(messageOutput?["value"] as? String, "Waiting")
        } else {
            XCTFail("Payload does not preserve original output structure")
        }
    }
}
