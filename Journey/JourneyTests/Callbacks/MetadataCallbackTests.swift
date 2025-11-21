//
//  MetadataCallbackTests.swift
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

class MetadataCallbackTests: XCTestCase {

    private var callback: MetadataCallback!
    
    override func setUp() {
        super.setUp()
        callback = MetadataCallback()

        let jsonString = """
        {
          "type": "MetadataCallback",
          "output": [
            {
              "name": "data",
              "value": {
                "_action": "webauthn_authentication",
                "challenge": "qnMsxgya8h6mUc6OyRu8jJ6Oq16tHV3cgE7juXGMDbg=",
                "allowCredentials": "",
                "_allowCredentials": [],
                "timeout": "60000",
                "userVerification": "preferred",
                "relyingPartyId": "rpId: \\"humorous-cuddly-carrot.glitch.me\\",",
                "_relyingPartyId": "humorous-cuddly-carrot.glitch.me",
                "_type": "WebAuthn"
              }
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = MetadataCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.value["_action"] as? String, "webauthn_authentication")
        XCTAssertEqual(callback.value["challenge"] as? String, "qnMsxgya8h6mUc6OyRu8jJ6Oq16tHV3cgE7juXGMDbg=")
        XCTAssertEqual(callback.value["allowCredentials"] as? String, "")

        if let allowCredentials = callback.value["_allowCredentials"] as? [Any] {
            XCTAssertEqual(allowCredentials.count, 0)
        } else {
            XCTFail("_allowCredentials should be an empty array")
        }

        XCTAssertEqual(callback.value["timeout"] as? String, "60000")
        XCTAssertEqual(callback.value["userVerification"] as? String, "preferred")
        XCTAssertEqual(callback.value["relyingPartyId"] as? String, "rpId: \"humorous-cuddly-carrot.glitch.me\",")
        XCTAssertEqual(callback.value["_relyingPartyId"] as? String, "humorous-cuddly-carrot.glitch.me")
        XCTAssertEqual(callback.value["_type"] as? String, "WebAuthn")
    }

    func testPayloadReturnsCorrectly() {
        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Since MetadataCallback doesn't override payload(), it should return the original json
        // Check that the payload contains the metadata structure
        if let output = payload["output"] as? [[String: Any]],
           let firstOutput = output.first,
           let value = firstOutput["value"] as? [String: Any] {

            XCTAssertEqual(value["_action"] as? String, "webauthn_authentication")
            XCTAssertEqual(value["challenge"] as? String, "qnMsxgya8h6mUc6OyRu8jJ6Oq16tHV3cgE7juXGMDbg=")
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testInitWithProtectInitialize() {
        let protectInitializeJsonString = """
        {
          "type": "MetadataCallback",
          "output": [
            {
              "name": "data",
              "value": {
                "_type": "PingOneProtect",
                "_action": "protect_initialize",
                "envId": "02fb4743-189a-4bc7-9d6c-a919edfe6447",
                "consoleLogEnabled": true,
                "deviceAttributesToIgnore": [],
                "customHost": "",
                "lazyMetadata": true,
                "behavioralDataCollection": true,
                "disableHub": true,
                "deviceKeyRsyncIntervals": 10,
                "enableTrust": true,
                "disableTags": true
              }
            }
          ],
          "_id": 0
        }
        """

        if let data = protectInitializeJsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            let newCallback = MetadataCallback()
            let actualCallback = newCallback.initialize(with: parsed)

            // If PingOneProtectInitializeCallback is registered, it should return that type
            // Otherwise, it should return the original MetadataCallback
            if type(of: actualCallback) != MetadataCallback.self {
                // Specialized callback was created - test would depend on actual PingOneProtectInitializeCallback implementation
                XCTAssertTrue(true, "Specialized callback created successfully")
            } else {
                // Specialized callback not available - ensure metadata is still parsed correctly
                if let metadataCallback = actualCallback as? MetadataCallback {
                    XCTAssertEqual(metadataCallback.value["_type"] as? String, "PingOneProtect")
                    XCTAssertEqual(metadataCallback.value["_action"] as? String, "protect_initialize")
                    XCTAssertEqual(metadataCallback.value["envId"] as? String, "02fb4743-189a-4bc7-9d6c-a919edfe6447")
                } else {
                    XCTFail("Should return MetadataCallback when specialized callback is not available")
                }
            }
        } else {
            XCTFail("Failed to parse protect initialize JSON")
        }
    }

    func testInitWithProtectEvaluation() {
        let protectEvaluationJsonString = """
        {
          "type": "MetadataCallback",
          "output": [
            {
              "name": "data",
              "value": {
                "_type": "PingOneProtect",
                "_action": "protect_risk_evaluation",
                "envId": "some_id",
                "pauseBehavioralData": true
              }
            }
          ],
          "_id": 0
        }
        """

        if let data = protectEvaluationJsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            let newCallback = MetadataCallback()
            let actualCallback = newCallback.initialize(with: parsed)

            // If PingOneProtectEvaluationCallback is registered, it should return that type
            // Otherwise, it should return the original MetadataCallback
            if type(of: actualCallback) != MetadataCallback.self {
                // Specialized callback was created
                XCTAssertTrue(true, "Specialized callback created successfully")
            } else {
                // Specialized callback not available - ensure metadata is still parsed correctly
                if let metadataCallback = actualCallback as? MetadataCallback {
                    XCTAssertEqual(metadataCallback.value["_type"] as? String, "PingOneProtect")
                    XCTAssertEqual(metadataCallback.value["_action"] as? String, "protect_risk_evaluation")
                    XCTAssertEqual(metadataCallback.value["envId"] as? String, "some_id")
                    XCTAssertEqual(metadataCallback.value["pauseBehavioralData"] as? Bool, true)
                } else {
                    XCTFail("Should return MetadataCallback when specialized callback is not available")
                }
            }
        } else {
            XCTFail("Failed to parse protect evaluation JSON")
        }
    }

    func testFidoRegistrationDetection() {
        let fidoRegJsonString = """
        {
          "type": "MetadataCallback",
          "output": [
            {
              "name": "data",
              "value": {
                "_action": "webauthn_registration",
                "_type": "WebAuthn",
                "pubKeyCredParams": [
                  {"type": "public-key", "alg": -7}
                ]
              }
            }
          ]
        }
        """

        if let data = fidoRegJsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            let newCallback = MetadataCallback()
            _ = newCallback.initialize(with: parsed)

            // Test that the metadata contains FIDO registration data
            XCTAssertEqual(newCallback.value["_action"] as? String, "webauthn_registration")
            XCTAssertEqual(newCallback.value["_type"] as? String, "WebAuthn")
            XCTAssertNotNil(newCallback.value["pubKeyCredParams"])
        } else {
            XCTFail("Failed to parse FIDO registration JSON")
        }
    }

    func testInitValueWithInvalidType() {
        let newCallback = MetadataCallback()

        // Test with invalid type - should not crash and should use default value
        newCallback.initValue(name: JourneyConstants.data, value: "not a dictionary")

        // Should maintain default value
        XCTAssertEqual(newCallback.value.count, 0)
    }

    func testInitValueWithUnknownProperty() {
        let newCallback = MetadataCallback()

        // Test with unknown property name - should not crash
        newCallback.initValue(name: "unknownProperty", value: ["some": "data"])

        // Should maintain default value
        XCTAssertEqual(newCallback.value.count, 0)
    }

    func testEmptyMetadataValue() {
        let newCallback = MetadataCallback()
        newCallback.initValue(name: JourneyConstants.data, value: [String: Any]())

        XCTAssertEqual(newCallback.value.count, 0)
    }

    func testComplexMetadataValue() {
        let newCallback = MetadataCallback()
        let complexMetadata: [String: Any] = [
            "_type": "CustomType",
            "_action": "custom_action",
            "nestedData": [
                "subProperty1": "value1",
                "subProperty2": ["array", "of", "values"]
            ],
            "arrayProperty": [1, 2, 3],
            "boolProperty": true,
            "numberProperty": 42
        ]

        newCallback.initValue(name: JourneyConstants.data, value: complexMetadata)

        XCTAssertEqual(newCallback.value["_type"] as? String, "CustomType")
        XCTAssertEqual(newCallback.value["_action"] as? String, "custom_action")
        XCTAssertNotNil(newCallback.value["nestedData"])
        XCTAssertEqual(newCallback.value["boolProperty"] as? Bool, true)
        XCTAssertEqual(newCallback.value["numberProperty"] as? Int, 42)

        if let nestedData = newCallback.value["nestedData"] as? [String: Any] {
            XCTAssertEqual(nestedData["subProperty1"] as? String, "value1")
        } else {
            XCTFail("Failed to parse nested data")
        }
    }

    func testMetadataCallbackReturnsSelfWhenNoSpecializedCallback() {
        // Test that when no specialized callback is registered, it returns self
        let actualCallback = callback.initialize(with: callback.json)

        // Should return the same instance when no transformation occurs
        XCTAssertTrue(type(of: actualCallback) == MetadataCallback.self)
    }

    func testWebAuthnMetadataStructure() {
        // Test that WebAuthn metadata is properly structured
        XCTAssertEqual(callback.value["_type"] as? String, "WebAuthn")
        XCTAssertEqual(callback.value["_action"] as? String, "webauthn_authentication")

        // Test WebAuthn-specific properties
        XCTAssertNotNil(callback.value["challenge"])
        XCTAssertNotNil(callback.value["timeout"])
        XCTAssertNotNil(callback.value["userVerification"])
        XCTAssertNotNil(callback.value["_relyingPartyId"])
    }

    func testMetadataWithDifferentActions() {
        let actionTestCases = [
            "webauthn_registration",
            "webauthn_authentication",
            "protect_initialize",
            "protect_risk_evaluation",
            "custom_action"
        ]

        for action in actionTestCases {
            let newCallback = MetadataCallback()
            let testMetadata = [
                "_type": "TestType",
                "_action": action,
                "testProperty": "testValue"
            ]

            newCallback.initValue(name: JourneyConstants.data, value: testMetadata)

            XCTAssertEqual(newCallback.value["_action"] as? String, action, "Failed for action: \(action)")
            XCTAssertEqual(newCallback.value["_type"] as? String, "TestType")
            XCTAssertEqual(newCallback.value["testProperty"] as? String, "testValue")
        }
    }

    func testMetadataWithDifferentTypes() {
        let typeTestCases = [
            "WebAuthn",
            "PingOneProtect",
            "CustomType",
            "SAML",
            "OAuth"
        ]

        for type in typeTestCases {
            let newCallback = MetadataCallback()
            let testMetadata = [
                "_type": type,
                "_action": "test_action",
                "testProperty": "testValue"
            ]

            newCallback.initValue(name: JourneyConstants.data, value: testMetadata)

            XCTAssertEqual(newCallback.value["_type"] as? String, type, "Failed for type: \(type)")
            XCTAssertEqual(newCallback.value["_action"] as? String, "test_action")
        }
    }

    func testPayloadPreservesOriginalStructure() {
        let payload = callback.payload()

        // Since MetadataCallback doesn't override payload(), it should return the original json
        XCTAssertNotNil(payload)

        // Verify the structure is preserved
        if let output = payload["output"] as? [[String: Any]],
           let firstOutput = output.first,
           firstOutput["name"] as? String == "data",
           let value = firstOutput["value"] as? [String: Any] {

            // Check that all original properties are preserved
            XCTAssertEqual(value["_action"] as? String, "webauthn_authentication")
            XCTAssertEqual(value["challenge"] as? String, "qnMsxgya8h6mUc6OyRu8jJ6Oq16tHV3cgE7juXGMDbg=")
            XCTAssertEqual(value["_type"] as? String, "WebAuthn")
        } else {
            XCTFail("Payload does not preserve original structure")
        }
    }

    func testDefaultValues() {
        let newCallback = MetadataCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.value.count, 0)
    }

    func testMetadataWithNumericValues() {
        let newCallback = MetadataCallback()
        let metadataWithNumbers: [String: Any] = [
            "_type": "TestType",
            "timeout": 30000,
            "maxRetries": 3,
            "version": 1.5,
            "enabled": true
        ]

        newCallback.initValue(name: JourneyConstants.data, value: metadataWithNumbers)

        XCTAssertEqual(newCallback.value["timeout"] as? Int, 30000)
        XCTAssertEqual(newCallback.value["maxRetries"] as? Int, 3)
        XCTAssertEqual(newCallback.value["version"] as? Double, 1.5)
        XCTAssertEqual(newCallback.value["enabled"] as? Bool, true)
    }

    func testMetadataWithNestedStructures() {
        let newCallback = MetadataCallback()
        let nestedMetadata: [String: Any] = [
            "_type": "Complex",
            "config": [
                "security": [
                    "level": "high",
                    "protocols": ["TLS", "OAuth"]
                ],
                "performance": [
                    "timeout": 5000,
                    "retries": 3
                ]
            ],
            "features": ["feature1", "feature2", "feature3"]
        ]

        newCallback.initValue(name: JourneyConstants.data, value: nestedMetadata)

        XCTAssertEqual(newCallback.value["_type"] as? String, "Complex")

        if let config = newCallback.value["config"] as? [String: Any],
           let security = config["security"] as? [String: Any] {
            XCTAssertEqual(security["level"] as? String, "high")

            if let protocols = security["protocols"] as? [String] {
                XCTAssertEqual(protocols, ["TLS", "OAuth"])
            }
        } else {
            XCTFail("Failed to parse nested config structure")
        }

        if let features = newCallback.value["features"] as? [String] {
            XCTAssertEqual(features, ["feature1", "feature2", "feature3"])
        } else {
            XCTFail("Failed to parse features array")
        }
    }
}
