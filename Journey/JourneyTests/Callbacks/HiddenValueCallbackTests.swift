//
//  HiddenValueCallbackTests.swift
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

class HiddenValueCallbackTests: XCTestCase {

    private var callback: HiddenValueCallback!
    
    override func setUp() {
        super.setUp()
        callback = HiddenValueCallback()

        let jsonString = """
        {
          "type": "HiddenValueCallback",
          "output": [
            {
              "name": "value",
              "value": "false"
            },
            {
              "name": "id",
              "value": "webAuthnOutcome"
            }
          ],
          "input": [
            {
              "name": "IDToken2",
              "value": "webAuthnOutcome"
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            // Initialize callback with parsed data
            callback = HiddenValueCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.value, "false")
        XCTAssertEqual(callback.hiddenId, "webAuthnOutcome")
    }

    func testPayloadReturnsCorrectly() {
        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "false")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testValueCanBeModified() {
        // Test that the value property can be changed after initialization
        XCTAssertEqual(callback.value, "false") // Initially "false" from JSON

        callback.value = "true"
        XCTAssertEqual(callback.value, "true")

        // Test payload with modified value
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "true")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = HiddenValueCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.id, value: "sessionToken")
        newCallback.initValue(name: JourneyConstants.value, value: "abc123xyz")

        XCTAssertEqual(newCallback.hiddenId, "sessionToken")
        XCTAssertEqual(newCallback.value, "abc123xyz")
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = HiddenValueCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.id, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.value, value: 456) // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.hiddenId, "")
        XCTAssertEqual(newCallback.value, "")
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = HiddenValueCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: 123)

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.hiddenId, "")
        XCTAssertEqual(newCallback.value, "")
    }

    func testPayloadWithDifferentValues() {
        let testValues = ["", "true", "false", "sessionId123", "token_abc_xyz", "complex-value-with-special-chars!@#"]

        for testValue in testValues {
            callback.value = testValue
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, testValue, "Failed for value: \(testValue)")
            } else {
                XCTFail("Payload structure is not as expected for value: \(testValue)")
            }
        }
    }

    func testHiddenIdValues() {
        let newCallback = HiddenValueCallback()
        let hiddenIdValues = ["", "simple", "webAuthnOutcome", "session_token_id", "complex-id-123"]

        for hiddenId in hiddenIdValues {
            newCallback.initValue(name: JourneyConstants.id, value: hiddenId)
            XCTAssertEqual(newCallback.hiddenId, hiddenId, "Failed for hiddenId: \(hiddenId)")
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic authentication scenario
        callback.initValue(name: JourneyConstants.id, value: "authenticationResult")
        callback.initValue(name: JourneyConstants.value, value: "success")

        // Verify all properties are set correctly
        XCTAssertEqual(callback.hiddenId, "authenticationResult")
        XCTAssertEqual(callback.value, "success")

        // System updates the value during authentication flow
        callback.value = "authenticated_token_xyz"

        // Test payload with updated value
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? String {
            XCTAssertEqual(value, "authenticated_token_xyz")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = HiddenValueCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.hiddenId, "")
        XCTAssertEqual(newCallback.value, "")
    }

    func testEmptyStringValues() {
        let newCallback = HiddenValueCallback()

        // Test with empty string values
        newCallback.initValue(name: JourneyConstants.id, value: "")
        newCallback.initValue(name: JourneyConstants.value, value: "")

        XCTAssertEqual(newCallback.hiddenId, "")
        XCTAssertEqual(newCallback.value, "")
    }

    func testValueWithSpecialCharacters() {
        let specialValues = [
            "value with spaces",
            "value-with-dashes",
            "value_with_underscores",
            "value.with.dots",
            "value@with#special$chars%",
            "base64EncodedValue==",
            "jwt.token.value"
        ]

        for specialValue in specialValues {
            callback.initValue(name: JourneyConstants.value, value: specialValue)
            XCTAssertEqual(callback.value, specialValue, "Failed for value: \(specialValue)")

            // Test payload with special value
            let payload = callback.payload()
            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? String {
                XCTAssertEqual(value, specialValue)
            } else {
                XCTFail("Payload structure is not as expected for value: \(specialValue)")
            }
        }
    }
}
