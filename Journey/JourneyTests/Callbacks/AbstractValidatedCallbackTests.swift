//
//  AbstractValidatedCallbackTests.swift
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

class AbstractValidatedCallbackTests: XCTestCase {

    private var callback: AbstractValidatedCallback!

    override func setUp() {
        super.setUp()

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
              "value": [
                "{ \\"params\\": { \\"minLength\\": 3 }, \\"policyRequirement\\": \\"MIN_LENGTH\\" }"
              ]
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
            callback = AbstractValidatedCallback()
            _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitWithPoliciesFromSampleData() {
        XCTAssertNotNil(callback.policies)

        // Test failedPolicies parsing
        XCTAssertEqual(callback.failedPolicies.count, 1)

        let policy = callback.failedPolicies[0]
        XCTAssertEqual(policy.policyRequirement, "MIN_LENGTH")

        if let params = policy.params,
           let minLength = params["minLength"] as? Int {
            XCTAssertEqual(minLength, 3)
        } else {
            XCTFail("Failed to parse minLength parameter")
        }

        XCTAssertFalse(callback.validateOnly)

        // Additional assertions for policies structure
        if let policyRequirements = callback.policies["policyRequirements"] as? [String] {
            XCTAssertEqual(policyRequirements.count, 6)
            XCTAssertEqual(policyRequirements[0], "REQUIRED")
            XCTAssertEqual(policyRequirements[5], "MAX_LENGTH")
        } else {
            XCTFail("Failed to parse policyRequirements")
        }

        if let policiesArray = callback.policies["policies"] as? [[String: Any]] {
            XCTAssertEqual(policiesArray.count, 6)

            let firstPolicy = policiesArray[0]
            XCTAssertEqual(firstPolicy["policyId"] as? String, "required")

            if let policyRequirements = firstPolicy["policyRequirements"] as? [String] {
                XCTAssertEqual(policyRequirements.first, "REQUIRED")
            } else {
                XCTFail("Failed to parse first policy requirements")
            }
        } else {
            XCTFail("Failed to parse policies array")
        }

        // Test prompt
        XCTAssertEqual(callback.prompt, "Username")
    }

    func testFailedPolicyWithMultipleEntries() {
        let newCallback = AbstractValidatedCallback()

        // Test with multiple failed policies
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: [
            "{ \"params\": { \"minLength\": 5 }, \"policyRequirement\": \"MIN_LENGTH\" }",
            "{ \"params\": { \"maxLength\": 10 }, \"policyRequirement\": \"MAX_LENGTH\" }",
            "{ \"params\": {}, \"policyRequirement\": \"REQUIRED\" }"
        ])

        XCTAssertEqual(newCallback.failedPolicies.count, 3)

        // Test first policy
        let firstPolicy = newCallback.failedPolicies[0]
        XCTAssertEqual(firstPolicy.policyRequirement, "MIN_LENGTH")
        XCTAssertEqual(firstPolicy.params?["minLength"] as? Int, 5)

        // Test second policy
        let secondPolicy = newCallback.failedPolicies[1]
        XCTAssertEqual(secondPolicy.policyRequirement, "MAX_LENGTH")
        XCTAssertEqual(secondPolicy.params?["maxLength"] as? Int, 10)

        // Test third policy
        let thirdPolicy = newCallback.failedPolicies[2]
        XCTAssertEqual(thirdPolicy.policyRequirement, "REQUIRED")
    }

    func testFailedPolicyDescription() {
        let policy = callback.failedPolicies[0]

        // Test failedDescription method
        let description = policy.failedDescription(for: "Username")
        XCTAssertEqual(description, "Username must be at least 3 character(s)")
    }

    func testFailedPolicyDescriptionWithDifferentTypes() {
        // Test various policy requirement descriptions
        let testCases: [(String, [String: Any], String, String)] = [
            ("REQUIRED", [:], "Password", "Password is required"),
            ("UNIQUE", [:], "Email", "Email must be unique"),
            ("VALID_EMAIL_ADDRESS_FORMAT", [:], "Email", "Invalid Email format"),
            ("VALID_PHONE_FORMAT", [:], "Phone", "Invalid phone number"),
            ("AT_LEAST_X_CAPITAL_LETTERS", ["numCaps": 2], "Password", "Password must contain at least 2 capital letter(s)"),
            ("AT_LEAST_X_NUMBERS", ["numNums": 1], "Password", "Password must contain at least 1 numeric value(s)"),
            ("MAX_LENGTH", ["maxLength": 50], "Username", "Username must be at most 50 character(s)"),
            ("CANNOT_CONTAIN_CHARACTERS", ["forbiddenChars": ["@", "#"]], "Username", "Username must not contain following characters: [\"@\", \"#\"]")
        ]

        for (requirement, params, propertyName, expectedDescription) in testCases {
            do {
                let jsonData = [
                    "params": params,
                    "policyRequirement": requirement
                ] as [String : Any]
                let policy = try FailedPolicy(propertyName, jsonData)
                let description = policy.failedDescription(for: propertyName)
                XCTAssertEqual(description, expectedDescription, "Failed for requirement: \(requirement)")
            } catch {
                XCTFail("Failed to create FailedPolicy for requirement: \(requirement)")
            }
        }
    }

    func testFailedPolicyWithUnknownRequirement() {
        do {
            let jsonData = [
                "params": [:],
                "policyRequirement": "UNKNOWN_POLICY"
            ] as [String : Any]
            let policy = try FailedPolicy("TestField", jsonData)
            let description = policy.failedDescription(for: "TestField")
            XCTAssertEqual(description, "TestField: Unknown policy requirement - UNKNOWN_POLICY")
        } catch {
            XCTFail("Should not throw error for unknown policy requirement")
        }
    }

    func testFailedPolicyInitializationError() {
        // Test FailedPolicy initialization with missing policyRequirement
        let jsonData = [
            "params": ["minLength": 5]
            // Missing policyRequirement
        ]

        XCTAssertThrowsError(try FailedPolicy("TestField", jsonData)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "FailedPolicy")
            XCTAssertEqual(nsError.code, 1)
        }
    }

    func testInitValueWithInvalidFailedPolicies() {
        let newCallback = AbstractValidatedCallback()

        // Test with invalid JSON strings in failedPolicies
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: [
            "invalid json string",
            "{ \"params\": { \"minLength\": 5 }, \"policyRequirement\": \"MIN_LENGTH\" }", // valid
            "{ invalid json }"
        ])

        // Should only parse the valid one
        XCTAssertEqual(newCallback.failedPolicies.count, 1)
        XCTAssertEqual(newCallback.failedPolicies[0].policyRequirement, "MIN_LENGTH")
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = AbstractValidatedCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.prompt, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.policies, value: "not a dict") // Invalid type
        newCallback.initValue(name: JourneyConstants.validateOnly, value: "not a bool") // Invalid type
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: "not an array") // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.prompt, "")
        XCTAssertEqual(newCallback.policies.count, 0)
        XCTAssertFalse(newCallback.validateOnly)
        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }

    func testValidateOnlyTrue() {
        let newCallback = AbstractValidatedCallback()
        newCallback.initValue(name: JourneyConstants.validateOnly, value: true)

        XCTAssertTrue(newCallback.validateOnly)
    }

    func testEmptyPolicies() {
        let newCallback = AbstractValidatedCallback()
        newCallback.initValue(name: JourneyConstants.policies, value: [String: Any]())

        XCTAssertEqual(newCallback.policies.count, 0)
    }

    func testEmptyFailedPolicies() {
        let newCallback = AbstractValidatedCallback()
        newCallback.initValue(name: JourneyConstants.failedPolicies, value: [String]())

        XCTAssertEqual(newCallback.failedPolicies.count, 0)
    }
}
