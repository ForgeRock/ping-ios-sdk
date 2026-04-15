//
//  MigrationProgressTests.swift
//  CommonsTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

final class MigrationProgressTests: XCTestCase {

    func testStartedCase() {
        let progress = MigrationProgress.started
        if case .started = progress {
            // pass
        } else {
            XCTFail("Expected .started case")
        }
    }

    func testInProgressCase() {
        let step = MigrationStep(id: "test", description: "Test step")
        let progress = MigrationProgress.inProgress(step: step, current: 1, total: 3)

        if case .inProgress(let s, let current, let total) = progress {
            XCTAssertEqual(s.description, "Test step")
            XCTAssertEqual(current, 1)
            XCTAssertEqual(total, 3)
        } else {
            XCTFail("Expected .inProgress case")
        }
    }

    func testStepCompletedCase() {
        let step = MigrationStep(id: "completed", description: "Completed step")
        let progress = MigrationProgress.stepCompleted(step: step)

        if case .stepCompleted(let s) = progress {
            XCTAssertEqual(s.description, "Completed step")
        } else {
            XCTFail("Expected .stepCompleted case")
        }
    }

    func testSuccessCase() {
        let message = "Migration successful"
        let progress = MigrationProgress.success(message: message)

        if case .success(let m) = progress {
            XCTAssertEqual(m, message)
        } else {
            XCTFail("Expected .success case")
        }
    }

    func testErrorCase() {
        let step = MigrationStep(id: "error", description: "Error step")
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let progress = MigrationProgress.error(step: step, underlyingError: underlyingError)

        if case .error(let s, let err) = progress {
            XCTAssertEqual(s.description, "Error step")
            let nsErr = err as NSError
            XCTAssertEqual(nsErr.domain, "TestDomain")
            XCTAssertEqual(nsErr.code, 42)
        } else {
            XCTFail("Expected .error case")
        }
    }
}
