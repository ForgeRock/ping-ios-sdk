//
//  ConsentMappingCallbackTests.swift
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

class ConsentMappingCallbackTests: XCTestCase {

    private var callback: ConsentMappingCallback!

    override func setUp() {
        super.setUp()
        callback = ConsentMappingCallback()

        let jsonString = """
        {
          "type": "ConsentMappingCallback",
          "output": [
            {
              "name": "name",
              "value": "managedUser_managedUser"
            },
            {
              "name": "displayName",
              "value": "Identity Mapping"
            },
            {
              "name": "icon",
              "value": ""
            },
            {
              "name": "accessLevel",
              "value": "Actual Profile"
            },
            {
              "name": "isRequired",
              "value": false
            },
            {
              "name": "message",
              "value": "This is Consent"
            },
            {
              "name": "fields",
              "value": ["a", "b"]
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            // Initialize callback with parsed data
            callback = ConsentMappingCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.name, "managedUser_managedUser")
        XCTAssertEqual(callback.displayName, "Identity Mapping")
        XCTAssertEqual(callback.icon, "")
        XCTAssertEqual(callback.accessLevel, "Actual Profile")
        XCTAssertFalse(callback.isRequired)
        XCTAssertEqual(callback.message, "This is Consent")
        XCTAssertEqual(callback.fields, ["a", "b"])
    }

    func testPayloadReturnsCorrectly() {
        callback.accepted = true

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithDefaultValue() {
        // Don't modify accepted - should be false by default

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertFalse(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testAcceptedPropertyCanBeModified() {
        // Test that the accepted property can be changed
        XCTAssertFalse(callback.accepted) // Initially false

        callback.accepted = true
        XCTAssertTrue(callback.accepted)

        callback.accepted = false
        XCTAssertFalse(callback.accepted)
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = ConsentMappingCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.name, value: "test_consent")
        newCallback.initValue(name: JourneyConstants.displayName, value: "Test Consent Display")
        newCallback.initValue(name: JourneyConstants.icon, value: "consent_icon.png")
        newCallback.initValue(name: JourneyConstants.accessLevel, value: "Limited Access")
        newCallback.initValue(name: JourneyConstants.isRequired, value: true)
        newCallback.initValue(name: JourneyConstants.fields, value: ["field1", "field2", "field3"])
        newCallback.initValue(name: JourneyConstants.message, value: "Please review and accept")

        XCTAssertEqual(newCallback.name, "test_consent")
        XCTAssertEqual(newCallback.displayName, "Test Consent Display")
        XCTAssertEqual(newCallback.icon, "consent_icon.png")
        XCTAssertEqual(newCallback.accessLevel, "Limited Access")
        XCTAssertTrue(newCallback.isRequired)
        XCTAssertEqual(newCallback.fields, ["field1", "field2", "field3"])
        XCTAssertEqual(newCallback.message, "Please review and accept")
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = ConsentMappingCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.name, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.displayName, value: 456) // Invalid type
        newCallback.initValue(name: JourneyConstants.icon, value: 789) // Invalid type
        newCallback.initValue(name: JourneyConstants.accessLevel, value: 012) // Invalid type
        newCallback.initValue(name: JourneyConstants.isRequired, value: "not a bool") // Invalid type
        newCallback.initValue(name: JourneyConstants.fields, value: "not an array") // Invalid type
        newCallback.initValue(name: JourneyConstants.message, value: 345) // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.displayName, "")
        XCTAssertEqual(newCallback.icon, "")
        XCTAssertEqual(newCallback.accessLevel, "")
        XCTAssertFalse(newCallback.isRequired)
        XCTAssertEqual(newCallback.fields, [])
        XCTAssertEqual(newCallback.message, "")
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = ConsentMappingCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: true)
        newCallback.initValue(name: "unknownProperty3", value: ["array", "value"])

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.displayName, "")
        XCTAssertEqual(newCallback.icon, "")
        XCTAssertEqual(newCallback.accessLevel, "")
        XCTAssertFalse(newCallback.isRequired)
        XCTAssertEqual(newCallback.fields, [])
        XCTAssertEqual(newCallback.message, "")
        XCTAssertFalse(newCallback.accepted)
    }

    func testEmptyFieldsArray() {
        let newCallback = ConsentMappingCallback()
        newCallback.initValue(name: JourneyConstants.fields, value: [String]())

        XCTAssertEqual(newCallback.fields, [])
    }

    func testSingleFieldInArray() {
        let newCallback = ConsentMappingCallback()
        newCallback.initValue(name: JourneyConstants.fields, value: ["singleField"])

        XCTAssertEqual(newCallback.fields, ["singleField"])
    }

    func testManyFieldsInArray() {
        let newCallback = ConsentMappingCallback()
        let manyFields = (1...10).map { "field\($0)" }

        newCallback.initValue(name: JourneyConstants.fields, value: manyFields)

        XCTAssertEqual(newCallback.fields.count, 10)
        XCTAssertEqual(newCallback.fields[0], "field1")
        XCTAssertEqual(newCallback.fields[9], "field10")
    }

    func testFieldsWithSpecialCharacters() {
        let newCallback = ConsentMappingCallback()
        let specialFields = ["field with spaces", "field-with-dashes", "field_with_underscores", "field.with.dots"]

        newCallback.initValue(name: JourneyConstants.fields, value: specialFields)

        XCTAssertEqual(newCallback.fields, specialFields)
    }

    func testIsRequiredBooleanValues() {
        let testCases = [true, false]

        for requiredValue in testCases {
            let newCallback = ConsentMappingCallback()
            newCallback.initValue(name: JourneyConstants.isRequired, value: requiredValue)

            XCTAssertEqual(newCallback.isRequired, requiredValue, "Failed for isRequired value: \(requiredValue)")
        }
    }

    func testPayloadWithBothAcceptedValues() {
        let testCases = [true, false]

        for acceptedValue in testCases {
            callback.accepted = acceptedValue
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? Bool {
                XCTAssertEqual(value, acceptedValue, "Failed for accepted value: \(acceptedValue)")
            } else {
                XCTFail("Payload structure is not as expected for accepted value: \(acceptedValue)")
            }
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic privacy consent scenario
        callback.initValue(name: JourneyConstants.name, value: "privacy_data_consent")
        callback.initValue(name: JourneyConstants.displayName, value: "Privacy Data Usage")
        callback.initValue(name: JourneyConstants.icon, value: "privacy_shield.svg")
        callback.initValue(name: JourneyConstants.accessLevel, value: "Personal Data")
        callback.initValue(name: JourneyConstants.isRequired, value: true)
        callback.initValue(name: JourneyConstants.fields, value: ["email", "phone", "address", "preferences"])
        callback.initValue(name: JourneyConstants.message, value: "We need your consent to process your personal data for improving our services.")

        // Verify all properties are set correctly
        XCTAssertEqual(callback.name, "privacy_data_consent")
        XCTAssertEqual(callback.displayName, "Privacy Data Usage")
        XCTAssertEqual(callback.icon, "privacy_shield.svg")
        XCTAssertEqual(callback.accessLevel, "Personal Data")
        XCTAssertTrue(callback.isRequired)
        XCTAssertEqual(callback.fields, ["email", "phone", "address", "preferences"])
        XCTAssertEqual(callback.message, "We need your consent to process your personal data for improving our services.")
        XCTAssertFalse(callback.accepted) // Default value

        // User accepts consent
        callback.accepted = true

        // Test payload with user acceptance
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = ConsentMappingCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.displayName, "")
        XCTAssertEqual(newCallback.icon, "")
        XCTAssertEqual(newCallback.accessLevel, "")
        XCTAssertFalse(newCallback.isRequired)
        XCTAssertEqual(newCallback.fields, [])
        XCTAssertEqual(newCallback.message, "")
        XCTAssertFalse(newCallback.accepted)
    }

    func testEmptyStringValues() {
        let newCallback = ConsentMappingCallback()

        // Test with empty string values
        newCallback.initValue(name: JourneyConstants.name, value: "")
        newCallback.initValue(name: JourneyConstants.displayName, value: "")
        newCallback.initValue(name: JourneyConstants.icon, value: "")
        newCallback.initValue(name: JourneyConstants.accessLevel, value: "")
        newCallback.initValue(name: JourneyConstants.message, value: "")

        XCTAssertEqual(newCallback.name, "")
        XCTAssertEqual(newCallback.displayName, "")
        XCTAssertEqual(newCallback.icon, "")
        XCTAssertEqual(newCallback.accessLevel, "")
        XCTAssertEqual(newCallback.message, "")
    }

    func testLongStringValues() {
        let newCallback = ConsentMappingCallback()
        let longMessage = "This is a very long consent message that explains in detail what data will be collected, how it will be used, who it will be shared with, and what rights the user has regarding their personal information according to GDPR and other privacy regulations."

        newCallback.initValue(name: JourneyConstants.message, value: longMessage)
        newCallback.initValue(name: JourneyConstants.displayName, value: "Very Long Display Name For Consent Mapping")

        XCTAssertEqual(newCallback.message, longMessage)
        XCTAssertEqual(newCallback.displayName, "Very Long Display Name For Consent Mapping")
    }

    func testIconPathValues() {
        let newCallback = ConsentMappingCallback()
        let iconPaths = [
            "",
            "icon.png",
            "/assets/icons/consent.svg",
            "https://example.com/icon.jpg",
            "data:image/svg+xml;base64,PHN2Zz4="
        ]

        for iconPath in iconPaths {
            newCallback.initValue(name: JourneyConstants.icon, value: iconPath)
            XCTAssertEqual(newCallback.icon, iconPath, "Failed for icon path: \(iconPath)")
        }
    }

    func testAccessLevelValues() {
        let newCallback = ConsentMappingCallback()
        let accessLevels = ["", "Read Only", "Limited Access", "Full Access", "Admin Level", "Actual Profile"]

        for accessLevel in accessLevels {
            newCallback.initValue(name: JourneyConstants.accessLevel, value: accessLevel)
            XCTAssertEqual(newCallback.accessLevel, accessLevel, "Failed for access level: \(accessLevel)")
        }
    }
}
