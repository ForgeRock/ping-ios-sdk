//
//  AccountParserTests.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOneMFA


// MARK: - AccountParser Tests

final class AccountParserTests: XCTestCase {

    // MARK: - Well-formed payload tests

    func testParseSingleRegionSingleUser() {
        // Given — real payload shape from PingOne.getInfo
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "c845dcd4-9696-45ce-b1b8-8797da941538",
                        "device": ["id": "05280532-42b0-4d29-93f2-9f2ed7acefc1"],
                        "environment": ["id": "803ca4d4-cd92-4cb8-9dd1-6fe68de0a5f0"]
                    ]
                ],
                "deviceRequirementsEvaluation": [
                    "status": "PASSED",
                    "deviceRequirementsDataHash": "wz8xty+2gFcfepr5zPpg/7TJENBtxZQhRSVw3pVidiU="
                ],
                "shouldRollback": 0
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].region, "NorthAmerica")
        XCTAssertEqual(accounts[0].id, "c845dcd4-9696-45ce-b1b8-8797da941538")
        XCTAssertEqual(accounts[0].deviceId, "05280532-42b0-4d29-93f2-9f2ed7acefc1")
        XCTAssertEqual(accounts[0].environmentId, "803ca4d4-cd92-4cb8-9dd1-6fe68de0a5f0")
    }

    func testParseMultipleRegionsMultipleUsers() {
        // Given
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "user-na-1",
                        "device": ["id": "device-na-1"],
                        "environment": ["id": "env-na-1"]
                    ],
                    [
                        "id": "user-na-2",
                        "device": ["id": "device-na-2"],
                        "environment": ["id": "env-na-2"]
                    ]
                ]
            ],
            "Europe": [
                "users": [
                    [
                        "id": "user-eu-1",
                        "device": ["id": "device-eu-1"],
                        "environment": ["id": "env-eu-1"]
                    ]
                ]
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then
        XCTAssertEqual(accounts.count, 3)

        let naAccounts = accounts.filter { $0.region == "NorthAmerica" }
        XCTAssertEqual(naAccounts.count, 2)

        let euAccounts = accounts.filter { $0.region == "Europe" }
        XCTAssertEqual(euAccounts.count, 1)
        XCTAssertEqual(euAccounts[0].id, "user-eu-1")
    }

    func testParseRegionWithEmptyUsersArray() {
        // Given — region exists but users array is empty
        let deviceInfo: [String: Any] = [
            "Australia": [
                "users": [[String: Any]]()
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then
        XCTAssertEqual(accounts.count, 0)
    }

    func testParseRegionWithExtraKeysIgnored() {
        // Given — non-"users" keys such as deviceRequirementsEvaluation and shouldRollback are ignored
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "user-1",
                        "device": ["id": "device-1"],
                        "environment": ["id": "env-1"]
                    ]
                ],
                "deviceRequirementsEvaluation": ["status": "PASSED"],
                "shouldRollback": 0
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — extra keys do not affect parsing
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].id, "user-1")
    }

    // MARK: - Edge cases

    func testParseNilDeviceInfo() {
        // When
        let accounts = AccountParser.parse(nil)

        // Then
        XCTAssertEqual(accounts.count, 0)
    }

    func testParseEmptyDictionary() {
        // When
        let accounts = AccountParser.parse([:])

        // Then
        XCTAssertEqual(accounts.count, 0)
    }

    func testParseRegionValueNotADictionary() {
        // Given — region value is a String instead of [String: Any]
        let deviceInfo: [String: Any] = [
            "NorthAmerica": "not-a-dict"
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — silently skipped
        XCTAssertEqual(accounts.count, 0)
    }

    func testParseMissingUsersKeyInRegion() {
        // Given — region dict has no "users" key
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "deviceRequirementsEvaluation": ["status": "PASSED"]
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — silently skipped
        XCTAssertEqual(accounts.count, 0)
    }

    func testParseMissingDeviceFieldYieldsEmptyDeviceId() {
        // Given — user dict is missing the "device" field
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "user-1",
                        // "device" missing
                        "environment": ["id": "env-1"]
                    ]
                ]
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — user is still returned with empty deviceId
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].id, "user-1")
        XCTAssertEqual(accounts[0].deviceId, "")
        XCTAssertEqual(accounts[0].environmentId, "env-1")
    }

    func testParseMissingEnvironmentIdYieldsEmptyEnvironmentId() {
        // Given — environment dict exists but has no "id" key
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "user-1",
                        "device": ["id": "device-1"],
                        "environment": ["wrongKey": "value"]
                    ]
                ]
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — user is returned with empty environmentId
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].environmentId, "")
    }

    func testParseMixedUsersAllIncluded() {
        // Given — one full user, one missing device field
        let deviceInfo: [String: Any] = [
            "NorthAmerica": [
                "users": [
                    [
                        "id": "full-user",
                        "device": ["id": "valid-device"],
                        "environment": ["id": "valid-env"]
                    ],
                    [
                        "id": "partial-user",
                        // "device" missing — falls back to ""
                        "environment": ["id": "partial-env"]
                    ]
                ]
            ]
        ]

        // When
        let accounts = AccountParser.parse(deviceInfo)

        // Then — both users are returned; partial user has empty deviceId
        XCTAssertEqual(accounts.count, 2)
        let partial = accounts.first { $0.id == "partial-user" }
        XCTAssertNotNil(partial)
        XCTAssertEqual(partial?.deviceId, "")
    }
}
