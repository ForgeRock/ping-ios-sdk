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
@testable import PingJourneyPlugin
@testable import PingJourney
@testable import PingDavinci
@testable import PingOrchestrate
internal import PingCommons

final class FidoLoggerTests: XCTestCase {

    // MARK: - Fido direct API

    func testRegisterRoutesLogsThroughInjectedLogger() {
        let mockLogger = MockFidoLogger()
        let fido = Fido()

        // "a" is a single valid base64 character. After stripping unknown characters,
        // the length (1) has remainder 1 mod 4, which Data(base64Encoded:) cannot decode
        // — it returns nil, causing the invalidChallenge guard to fire synchronously.
        let options: [String: Any] = [
            "challenge": "a",
            "rp": ["id": "example.com", "name": "Example"],
            "user": ["id": "userId", "name": "user", "displayName": "User"],
            "pubKeyCredParams": [["type": "public-key", "alg": -7]]
        ]
        let exp = expectation(description: "completion called")
        fido.register(options: options, window: MockASPresentationAnchor(), logger: mockLogger) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(mockLogger.hasMessages, "Expected register to emit log messages through the injected logger")
        XCTAssertTrue(mockLogger.messages.contains { $0.level == "e" }, "Expected an error-level log for the invalid challenge")
    }

    func testAuthenticateRoutesLogsThroughInjectedLogger() {
        let mockLogger = MockFidoLogger()
        let fido = Fido()

        // See note in testRegisterRoutesLogsThroughInjectedLogger about the challenge string.
        let options: [String: Any] = [
            "challenge": "a",
            "rpId": "example.com",
            "userVerification": "preferred"
        ]
        let exp = expectation(description: "completion called")
        fido.authenticate(options: options, window: MockASPresentationAnchor(), logger: mockLogger) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(mockLogger.hasMessages, "Expected authenticate to emit log messages through the injected logger")
        XCTAssertTrue(mockLogger.messages.contains { $0.level == "e" }, "Expected an error-level log for the invalid challenge")
    }

    func testNoLoggerInjectedDoesNotCrash() {
        let mockLogger = MockFidoLogger()
        let fido = Fido()
        let options: [String: Any] = [
            "challenge": "a",
            "rpId": "example.com"
        ]
        let exp = expectation(description: "completion called")
        fido.authenticate(options: options, window: MockASPresentationAnchor()) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertFalse(mockLogger.hasMessages, "No logger injected — mock logger should have received no calls")
    }

    // MARK: - Collector / Callback propagation
    //
    // These tests guard the four call sites that pass `logger:` into the underlying Fido
    // instance. Removing the propagation in any of them must fail a test here.

    @MainActor
    func testFidoRegistrationCollectorPropagatesWorkflowLoggerToFido() async {
        let mockLogger = MockFidoLogger()
        let mockFido = MockFido()
        let davinci = DaVinci.createDaVinci { config in
            config.logger = mockLogger
        }
        let collector = FidoRegistrationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]
        ])
        collector.davinci = davinci
        collector.fido = mockFido
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)

        _ = await collector.register(window: MockASPresentationAnchor())

        XCTAssertTrue(mockFido.capturedLogger as? MockFidoLogger === mockLogger,
                      "Collector must pass the DaVinci config logger to fido.register")
    }

    @MainActor
    func testFidoAuthenticationCollectorPropagatesWorkflowLoggerToFido() async {
        let mockLogger = MockFidoLogger()
        let mockFido = MockFido()
        let davinci = DaVinci.createDaVinci { config in
            config.logger = mockLogger
        }
        let collector = FidoAuthenticationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]
        ])
        collector.davinci = davinci
        collector.fido = mockFido
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)

        _ = await collector.authenticate(window: MockASPresentationAnchor())

        XCTAssertTrue(mockFido.capturedLogger as? MockFidoLogger === mockLogger,
                      "Collector must pass the DaVinci config logger to fido.authenticate")
    }

    @MainActor
    func testFidoRegistrationCallbackPropagatesWorkflowLoggerToFido() async {
        let mockLogger = MockFidoLogger()
        let mockFido = MockFido()
        let journey = Journey.createJourney { config in
            config.logger = mockLogger
        }
        let callback = FidoRegistrationCallback()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        callback.journey = journey
        callback.continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.fido = mockFido
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)

        _ = await callback.register(window: MockASPresentationAnchor())

        XCTAssertTrue(mockFido.capturedLogger as? MockFidoLogger === mockLogger,
                      "Callback must pass the Journey config logger to fido.register")
    }

    @MainActor
    func testFidoAuthenticationCallbackPropagatesWorkflowLoggerToFido() async {
        let mockLogger = MockFidoLogger()
        let mockFido = MockFido()
        let journey = Journey.createJourney { config in
            config.logger = mockLogger
        }
        let callback = FidoAuthenticationCallback()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        callback.journey = journey
        callback.continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.fido = mockFido
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)

        _ = await callback.authenticate(window: MockASPresentationAnchor())

        XCTAssertTrue(mockFido.capturedLogger as? MockFidoLogger === mockLogger,
                      "Callback must pass the Journey config logger to fido.authenticate")
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

    var hasMessages: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !_messages.isEmpty
    }

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
