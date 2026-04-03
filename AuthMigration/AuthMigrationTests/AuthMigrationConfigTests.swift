//
//  AuthMigrationConfigTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingAuthMigration

final class AuthMigrationConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = AuthMigrationConfig()
        XCTAssertNil(config.accessGroup)
        XCTAssertNil(config.logger)
        XCTAssertTrue(config.cleanupLegacyData)
        XCTAssertNil(config.oathStorage)
        XCTAssertNil(config.pushStorage)
    }

    func testCustomValues() {
        let config = AuthMigrationConfig()
        config.accessGroup = "com.example.shared"
        config.cleanupLegacyData = false

        XCTAssertEqual(config.accessGroup, "com.example.shared")
        XCTAssertFalse(config.cleanupLegacyData)
    }

    func testDSLConfiguration() {
        let config = AuthMigrationConfig()
        let closure: (AuthMigrationConfig) -> Void = { c in
            c.cleanupLegacyData = false
            c.accessGroup = "com.example.group"
        }
        closure(config)

        XCTAssertFalse(config.cleanupLegacyData)
        XCTAssertEqual(config.accessGroup, "com.example.group")
    }
}
