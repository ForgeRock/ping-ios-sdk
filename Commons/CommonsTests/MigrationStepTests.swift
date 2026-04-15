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

    func testIdAndDescription() {
        let step = MigrationStep(id: "importData", description: "Import legacy data")
        XCTAssertEqual(step.id, "importData")
        XCTAssertEqual(step.description, "Import legacy data")
    }

    func testCustomStringConvertible() {
        let step = MigrationStep(id: "migrate", description: "Migrate credentials")
        XCTAssertEqual("\(step)", "Migrate credentials")
    }

    func testEquatableUsesId() {
        let step1 = MigrationStep(id: "cleanup", description: "Cleanup legacy data")
        let step2 = MigrationStep(id: "cleanup", description: "Different description")
        XCTAssertEqual(step1, step2)
    }

    func testNotEqualWithDifferentId() {
        let step1 = MigrationStep(id: "step1", description: "Same description")
        let step2 = MigrationStep(id: "step2", description: "Same description")
        XCTAssertNotEqual(step1, step2)
    }

    func testHashableUsesId() {
        let step1 = MigrationStep(id: "cleanup", description: "Cleanup legacy data")
        let step2 = MigrationStep(id: "cleanup", description: "Different description")
        XCTAssertEqual(step1.hashValue, step2.hashValue)

        let set: Set<MigrationStep> = [step1, step2]
        XCTAssertEqual(set.count, 1)
    }

    func testIdentifiable() {
        let step = MigrationStep(id: "importData", description: "Import legacy data")
        XCTAssertEqual(step.id, "importData")
    }

    func testStaticExtension() {
        XCTAssertEqual(TestMigrationStep.exampleStep.id, "example")
        XCTAssertEqual(TestMigrationStep.exampleStep.description, "Example step")
    }
}

// MARK: - Test Extension

private extension MigrationStep {
    static let exampleStep = MigrationStep(id: "example", description: "Example step")
}

private enum TestMigrationStep {
    static let exampleStep = MigrationStep.exampleStep
}
