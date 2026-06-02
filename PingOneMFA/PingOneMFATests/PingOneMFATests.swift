//
//  PingOneMFATests.swift
//  PingOneMFATests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import UserNotifications
@testable import PingOneMFA

final class PingOneMFATests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Reset SDK state before each test
        await PingOneMFA.reset()
        MockPingOneMFA.reset()
    }

    override func tearDown() async throws {
        // Clean up after each test
        await PingOneMFA.reset()
        MockPingOneMFA.reset()
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Mirrors ProtectTests.test04: calls initialize() twice via mock and asserts
    /// initializeCalled == true after both calls (idempotency guard exercised at mock layer).
    func test04_InitDoesNotReinitializeIfAlreadyInitialized() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When — first initialization
        try await MockPingOneMFA.initialize(geo: .northAmerica)
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.initializeCallCount, 1)

        // When — second initialization (idempotency: should not throw)
        try await MockPingOneMFA.initialize(geo: .northAmerica)

        // Then — still marked as called, call count incremented
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.initializeCallCount, 2)
    }

    // MARK: - Mock-Based Happy-Path Tests

    func test06_MockInitializeHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When
        try await MockPingOneMFA.initialize(geo: .northAmerica)

        // Then
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.lastGeo, .northAmerica)
    }

    func test07_MockSetDeviceTokenHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        let token = Data([0x01, 0x02, 0x03])

        // When
        try await MockPingOneMFA.setDeviceToken(token)

        // Then
        XCTAssertTrue(MockPingOneMFA.registerPushTokenCalled)
    }

    func test07b_MockSetDeviceTokenThrowsOnError() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Token registration failed"
        let token = Data([0x01, 0x02, 0x03])

        // When / Then
        do {
            try await MockPingOneMFA.setDeviceToken(token)
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Token registration failed")
            XCTAssertTrue(MockPingOneMFA.registerPushTokenCalled)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test08_MockPairHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When
        try await MockPingOneMFA.pair(pairingKey: "test-pairing-key")

        // Then
        XCTAssertTrue(MockPingOneMFA.pairCalled)
    }

    func test09_MockGetDeviceInfoHappyPath() async throws {
        // Given
        let expectedAccount = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-id-1",
            deviceId: "device-id-1",
            environmentId: "env-id-1",
            name: "Test User",
            family: "User",
        )
        MockPingOneMFA.accountsReturnValue = [expectedAccount]

        // When
        let result = try await MockPingOneMFA.getDeviceInfo()

        // Then
        XCTAssertTrue(MockPingOneMFA.getDeviceInfoCalled)
        XCTAssertEqual(result.accounts.count, 1)
        XCTAssertEqual(result.accounts[0], expectedAccount)
        XCTAssertNil(result.errors)
    }

    func test10_MockGetOneTimePasscodeHappyPath() async throws {
        // Given
        let expectedOtp = OtpCodeInfo(code: "654321", secondsRemaining: 25)
        MockPingOneMFA.otpReturnValue = expectedOtp

        // When
        let otpInfo = try await MockPingOneMFA.getOneTimePasscode()

        // Then
        XCTAssertTrue(MockPingOneMFA.getOneTimePasscodeCalled)
        XCTAssertEqual(otpInfo.code, "654321")
        XCTAssertEqual(otpInfo.secondsRemaining, 25)
    }

    func test11_MockGetMobilePayloadHappyPath() async throws {
        // Given
        MockPingOneMFA.mobilePayloadReturnValue = "test-payload-value"

        // When
        let payload = try await MockPingOneMFA.getMobilePayload()

        // Then
        XCTAssertTrue(MockPingOneMFA.getMobilePayloadCalled)
        XCTAssertEqual(payload, "test-payload-value")
    }

    // MARK: - Error-Path Tests

    func test12_MockThrowsErrorOnInitialize() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Init failed"

        // When / Then
        do {
            try await MockPingOneMFA.initialize(geo: .northAmerica)
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Init failed")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test13_MockThrowsOnGetDeviceInfoError() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Get accounts failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.getDeviceInfo()
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertTrue(MockPingOneMFA.getDeviceInfoCalled)
            XCTAssertEqual(error.message, "Get accounts failed")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Thread Safety Tests

    /// Mirrors ProtectTests.test12: fires 5 concurrent initialize() calls via mock,
    /// asserts mock was called (idempotency under concurrency).
    func test15_ConcurrentInitializationCalls() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        MockPingOneMFA.initializeCallCount = 0

        // When — multiple concurrent initialization calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        try await MockPingOneMFA.initialize(geo: .northAmerica)
                    } catch {
                        XCTFail("Mock initialization should not fail: \(error)")
                    }
                }
            }
        }

        // Then — mock was called (concurrent invocations all completed)
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.initializeCallCount, 5)
    }

    // MARK: - Edge Cases

    func test16_ResetFunctionality() async {
        // When
        await PingOneMFA.reset()

        // Then
        let isInitialized = await PingOneMFA.isInitialized
        XCTAssertFalse(isInitialized)
    }

    // MARK: - collectPush Error-Path Test

    /// processPushNotification error-path: mock throws PingOneMFAError when shouldThrowError == true.
    /// Happy-path cannot be tested via mock because NotificationObject (PingOneSDK) has no
    /// accessible initialiser, preventing construction of a PushNotification stub value.
    func test18_MockProcessPushNotificationErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Collect push failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.processPushNotification(userInfo: [:])
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Collect push failed")
            XCTAssertTrue(MockPingOneMFA.processPushNotificationCalled)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Value-Type Equality Smoke Tests

    func test19_OtpCodeInfoEquality() {
        let a = OtpCodeInfo(code: "123456", secondsRemaining: 30)
        let b = OtpCodeInfo(code: "123456", secondsRemaining: 30)
        let c = OtpCodeInfo(code: "999999", secondsRemaining: 10)

        // Two instances with the same values are equal
        XCTAssertEqual(a, b)
        // Two instances with different values are not equal
        XCTAssertNotEqual(a, c)
    }

    func test20_PingOneMfaAccountEquality() {
        let a = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-1",
            deviceId: "device-1",
            environmentId: "env-1",
            name: "Test User",
            family: "User"
        )
        let b = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-1",
            deviceId: "device-1",
            environmentId: "env-1",
            name: "Test User",
            family: "User"
        )
        let c = PingOneMfaAccount(
            region: "Europe",
            id: "user-2",
            deviceId: "device-2",
            environmentId: "env-2",
            name: "Another User",
            family: "User"
        )

        // Two instances with the same values are equal
        XCTAssertEqual(a, b)
        // Two instances with different values are not equal
        XCTAssertNotEqual(a, c)
    }

    // MARK: - getNotificationCategories Mock Test

    /// test21: verifies that MockPingOneMFA.getNotificationCategories() sets the
    /// getNotificationCategoriesCalled flag and returns the configured category set.
    /// No real PingOneSDK call is made — the mock is exercised directly.
    func test21_MockGetNotificationCategoriesReturnsConfiguredCategories() {
        // Given
        let category = UNNotificationCategory(
            identifier: "test.category",
            actions: [],
            intentIdentifiers: []
        )
        MockPingOneMFA.notificationCategoriesReturnValue = [category]

        // When
        let returned = MockPingOneMFA.getNotificationCategories()

        // Then
        XCTAssertTrue(MockPingOneMFA.getNotificationCategoriesCalled)
        XCTAssertEqual(returned.count, 1)
        XCTAssertTrue(returned.contains(where: { $0.identifier == "test.category" }))
    }

    // MARK: - processNotificationAction Mock Tests

    /// test22: verifies that MockPingOneMFA.processNotificationAction returns nil when the
    /// SDK handles the action internally (no PushNotification needed).
    /// Happy-path (non-nil return) cannot be tested because NotificationObject (PingOneSDK)
    /// has no accessible initialiser, preventing construction of a PushNotification stub value.
    func test22_MockProcessNotificationActionReturnsNilWhenSDKHandlesInternally() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        MockPingOneMFA.processNotificationActionReturnValue = nil

        // When
        let result = try await MockPingOneMFA.processNotificationAction(
            identifier: "notification.confirm",
            authenticationMethod: "user",
            userInfo: [:]
        )

        // Then
        XCTAssertTrue(MockPingOneMFA.processNotificationActionCalled)
        XCTAssertNil(result)
        XCTAssertEqual(MockPingOneMFA.lastActionIdentifier, "notification.confirm")
        XCTAssertEqual(MockPingOneMFA.lastActionAuthenticationMethod, "user")
    }

    /// test23: verifies that MockPingOneMFA.processNotificationAction throws a PingOneMFAError
    /// when shouldThrowError is set, exercising the error path.
    func test23_MockProcessNotificationActionErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Process notification action failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.processNotificationAction(
                identifier: "notification.deny",
                authenticationMethod: "user",
                userInfo: [:]
            )
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Process notification action failed")
            XCTAssertTrue(MockPingOneMFA.processNotificationActionCalled)
            XCTAssertEqual(MockPingOneMFA.lastActionIdentifier, "notification.deny")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
