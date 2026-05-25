//
//  PingOneMFAErrorTests.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOneMFA


// MARK: - PingOneMFAError Tests

final class PingOneMFAErrorTests: XCTestCase {

    func testInitWithMessage() {
        let error = PingOneMFAError("Test error message")

        XCTAssertEqual(error.message, "Test error message")
    }

    func testErrorDescriptionMatchesMessage() {
        let message = "SDK initialization failed: connection timed out"
        let error = PingOneMFAError(message)

        XCTAssertEqual(error.errorDescription, message)
    }

    func testErrorDescriptionEqualsMessage() {
        let error = PingOneMFAError("some error")

        XCTAssertEqual(error.errorDescription, error.message)
    }

    func testConformsToError() {
        // Compile-time check: PingOneMFAError conforms to Error
        let error: Error = PingOneMFAError("error conformance test")
        XCTAssertNotNil(error)
    }

    func testConformsToLocalizedError() {
        // Compile-time check: PingOneMFAError conforms to LocalizedError
        let error: LocalizedError = PingOneMFAError("localized error test")
        XCTAssertEqual(error.errorDescription, "localized error test")
    }

    func testSendableConformance() {
        // Compile-time check: PingOneMFAError is Sendable (can be used in async context)
        let error = PingOneMFAError("sendable test")
        Task {
            let _ = error.message
        }
        XCTAssertEqual(error.message, "sendable test")
    }

    func testErrorCanBeThrownAndCaught() {
        let expectedMessage = "thrown error message"

        do {
            throw PingOneMFAError(expectedMessage)
        } catch let caught as PingOneMFAError {
            XCTAssertEqual(caught.message, expectedMessage)
            XCTAssertEqual(caught.errorDescription, expectedMessage)
        } catch {
            XCTFail("Wrong error type caught: \(error)")
        }
    }

    func testEmptyMessage() {
        let error = PingOneMFAError("")

        XCTAssertEqual(error.message, "")
        XCTAssertEqual(error.errorDescription, "")
    }
}
