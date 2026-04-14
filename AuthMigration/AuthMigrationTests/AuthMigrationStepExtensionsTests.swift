//
//  AuthMigrationStepExtensionsTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingCommons
@testable import PingAuthMigration

final class AuthMigrationStepExtensionsTests: XCTestCase {

    func testStepDescriptions() {
        XCTAssertEqual(MigrationStep.importLegacyData.description, "Import legacy data")
        XCTAssertEqual(MigrationStep.migrateCredentials.description, "Migrate credentials")
        XCTAssertEqual(MigrationStep.cleanup.description, "Cleanup legacy data")
    }
}
