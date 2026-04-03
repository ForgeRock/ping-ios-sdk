//
//  MigrationStepTests.swift
//  CommonsTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

final class MigrationStepTests: XCTestCase {

    func testDescription() {
        let step = MigrationStep(description: "Import legacy data")
        XCTAssertEqual(step.description, "Import legacy data")
    }

    func testCustomStringConvertible() {
        let step = MigrationStep(description: "Migrate credentials")
        XCTAssertEqual("\(step)", "Migrate credentials")
    }

    func testStaticExtension() {
        XCTAssertEqual(TestMigrationStep.exampleStep.description, "Example step")
    }
}

// MARK: - Test Extension

private extension MigrationStep {
    static let exampleStep = MigrationStep(description: "Example step")
}

private enum TestMigrationStep {
    static let exampleStep = MigrationStep.exampleStep
}
