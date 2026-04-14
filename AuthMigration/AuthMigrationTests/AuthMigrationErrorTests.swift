//
//  AuthMigrationErrorTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingAuthMigration

final class AuthMigrationErrorTests: XCTestCase {

    func testNoLegacyDataFound_hasDescription() {
        let error = AuthMigrationError.noLegacyDataFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("No legacy") == true)
    }

    func testFailedToReadLegacyData_wrapsError() {
        let inner = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "read failure"])
        let error = AuthMigrationError.failedToReadLegacyData(inner)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("read failure") == true)
    }

    func testFailedToDecryptLegacyData_wrapsError() {
        let inner = NSError(domain: "TestDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "decryption failed"])
        let error = AuthMigrationError.failedToDecryptLegacyData(inner)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("decrypt") == true)
    }

    func testFailedToDeserializeLegacyData_includesMessage() {
        let message = "unarchiving failed because of a bad class"
        let error = AuthMigrationError.failedToDeserializeLegacyData(message)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains(message) == true)
    }

    func testFailedToSaveOathCredentials_wrapsError() {
        let inner = NSError(domain: "TestDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "storage error"])
        let error = AuthMigrationError.failedToSaveOathCredentials(inner)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("OATH") == true)
    }

    func testFailedToSavePushCredentials_wrapsError() {
        let inner = NSError(domain: "TestDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "storage error"])
        let error = AuthMigrationError.failedToSavePushCredentials(inner)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Push") == true)
    }

    func testFailedToCleanupLegacyData_wrapsError() {
        let inner = NSError(domain: "TestDomain", code: 5, userInfo: [NSLocalizedDescriptionKey: "delete error"])
        let error = AuthMigrationError.failedToCleanupLegacyData(inner)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("cleanup") == true)
    }
}
