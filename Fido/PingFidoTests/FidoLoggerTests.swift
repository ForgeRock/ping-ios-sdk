//
//  FidoLoggerTests.swift
//  PingFidoTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido
@testable import PingLogger

final class FidoLoggerTests: XCTestCase {

    func testLoggerDefaultsToNil() {
        let fido = Fido()
        XCTAssertNil(fido.logger, "Fido.logger should default to nil so callers opt in")
    }

    func testRegisterRoutesLogsThroughInjectedLogger() {
        let mockLogger = MockFidoLogger()
        let fido = Fido()
        fido.logger = mockLogger

        let options: [String: Any] = [
            "challenge": "!!!not-valid-base64!!!",
            "rp": ["id": "example.com", "name": "Example"],
            "user": ["id": "userId", "name": "user", "displayName": "User"],
            "pubKeyCredParams": [["type": "public-key", "alg": -7]]
        ]
        let exp = expectation(description: "completion called")
        fido.register(options: options, window: MockASPresentationAnchor()) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(mockLogger.hasMessages, "Expected register to emit log messages through the injected logger")
        XCTAssertTrue(mockLogger.messages.contains { $0.level == "e" }, "Expected an error-level log for the invalid challenge")
    }

    func testAuthenticateRoutesLogsThroughInjectedLogger() {
        let mockLogger = MockFidoLogger()
        let fido = Fido()
        fido.logger = mockLogger

        let options: [String: Any] = [
            "challenge": "!!!not-valid-base64!!!",
            "rpId": "example.com",
            "userVerification": "preferred"
        ]
        let exp = expectation(description: "completion called")
        fido.authenticate(options: options, window: MockASPresentationAnchor()) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(mockLogger.hasMessages, "Expected authenticate to emit log messages through the injected logger")
        XCTAssertTrue(mockLogger.messages.contains { $0.level == "e" }, "Expected an error-level log for the invalid challenge")
    }

    func testNoLoggerInjectedDoesNotCrash() {
        let fido = Fido()
        XCTAssertNil(fido.logger)

        let options: [String: Any] = [
            "challenge": "!!!not-valid-base64!!!",
            "rpId": "example.com"
        ]
        let exp = expectation(description: "completion called")
        fido.authenticate(options: options, window: MockASPresentationAnchor()) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

final class MockFidoLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [(level: String, message: String)] = []

    var messages: [(level: String, message: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    var hasMessages: Bool { !messages.isEmpty }

    private func append(_ level: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        _messages.append((level: level, message: message))
    }

    func i(_ message: String) { append("i", message) }
    func d(_ message: String) { append("d", message) }
    func w(_ message: String, error: Error?) { append("w", message) }
    func e(_ message: String, error: Error?) { append("e", message) }
}
