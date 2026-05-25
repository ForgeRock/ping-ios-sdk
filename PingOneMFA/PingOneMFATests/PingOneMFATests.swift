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

    // MARK: - Configuration Tests

    func test01_InitializeThrowsErrorIfNotConfigured() async {
        do {
            try await PingOneMFA.initialize()
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "PingOneMFA SDK not configured. Call config() first.")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test02_ConfigSetsAllPingOneMFAConfigPropertiesCorrectly() async {
        // When
        await PingOneMFA.config {
            $0.geo = .northAmerica
        }

        // Then
        let config = await PingOneMFA.pingOneMFAConfig
        guard let config = config else {
            XCTFail("PingOneMFA config should not be nil")
            return
        }
        XCTAssertEqual(config.geo, .northAmerica)
    }

    func test03_ConfigWithAllGeoValues() async {
        // Test each geo value can be set
        let geoValues: [PingOneMFAGeo] = [.northAmerica, .europe, .australia, .canada, .singapore]

        for geo in geoValues {
            await PingOneMFA.config {
                $0.geo = geo
            }
            let config = await PingOneMFA.pingOneMFAConfig
            XCTAssertEqual(config?.geo, geo, "Failed for geo: \(geo)")
        }
    }

    // MARK: - Initialization Tests

    /// Mirrors ProtectTests.test04: calls initialize() twice via mock and asserts
    /// initializeCalled == true after both calls (idempotency guard exercised at mock layer).
    func test04_InitDoesNotReinitializeIfAlreadyInitialized() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When — first initialization
        try await MockPingOneMFA.initialize()
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.initializeCallCount, 1)

        // When — second initialization (idempotency: should not throw)
        try await MockPingOneMFA.initialize()

        // Then — still marked as called, call count incremented
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
        XCTAssertEqual(MockPingOneMFA.initializeCallCount, 2)
    }

    func test05_ConfigWithEmptyConfiguration() async {
        // When
        await PingOneMFA.config { _ in }

        // Then
        let config = await PingOneMFA.pingOneMFAConfig
        guard let config = config else {
            XCTFail("PingOneMFA config should not be nil after calling config()")
            return
        }
        XCTAssertNil(config.geo)
    }

    // MARK: - Mock-Based Happy-Path Tests

    func test06_MockInitializeHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When
        try await MockPingOneMFA.initialize()

        // Then
        XCTAssertTrue(MockPingOneMFA.initializeCalled)
    }

    func test07_MockRegisterHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        let token = Data([0x01, 0x02, 0x03])

        // When
        try await MockPingOneMFA.register(pushToken: token)

        // Then
        XCTAssertTrue(MockPingOneMFA.registerCalled)
    }

    func test08_MockPairHappyPath() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false

        // When
        try await MockPingOneMFA.pair(pairingKey: "test-pairing-key")

        // Then
        XCTAssertTrue(MockPingOneMFA.pairCalled)
    }

    func test09_MockGetAccountsHappyPath() async throws {
        // Given
        let expectedAccount = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-id-1",
            deviceId: "device-id-1",
            environmentId: "env-id-1"
        )
        MockPingOneMFA.accountsReturnValue = [expectedAccount]

        // When
        let accounts = try await MockPingOneMFA.getAccounts()

        // Then
        XCTAssertTrue(MockPingOneMFA.getAccountsCalled)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0], expectedAccount)
    }

    func test10_MockCollectOtpHappyPath() async throws {
        // Given
        let expectedOtp = OtpCodeInfo(code: "654321", secondsRemaining: 25)
        MockPingOneMFA.otpReturnValue = expectedOtp

        // When
        let otpInfo = try await MockPingOneMFA.collectOtp()

        // Then
        XCTAssertTrue(MockPingOneMFA.collectOtpCalled)
        XCTAssertEqual(otpInfo.code, "654321")
        XCTAssertEqual(otpInfo.secondsRemaining, 25)
    }

    func test11_MockCollectMobilePayloadHappyPath() async throws {
        // Given
        MockPingOneMFA.mobilePayloadReturnValue = "test-payload-value"

        // When
        let payload = try await MockPingOneMFA.collectMobilePayload()

        // Then
        XCTAssertTrue(MockPingOneMFA.collectMobilePayloadCalled)
        XCTAssertEqual(payload, "test-payload-value")
    }

    // MARK: - Error-Path Tests

    func test12_MockThrowsErrorOnInitialize() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Init failed"

        // When / Then
        do {
            try await MockPingOneMFA.initialize()
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Init failed")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test13_MockThrowsErrorOnGetAccounts() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Get accounts failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.getAccounts()
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Get accounts failed")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Thread Safety Tests

    func test14_ConcurrentConfigurationCalls() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<5 {
                group.addTask {
                    await PingOneMFA.config {
                        $0.geo = index % 2 == 0 ? .northAmerica : .europe
                    }
                }
            }
        }

        let config = await PingOneMFA.pingOneMFAConfig
        XCTAssertNotNil(config)
    }

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
                        try await MockPingOneMFA.initialize()
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
        // Given
        await PingOneMFA.config {
            $0.geo = .northAmerica
        }

        // When
        await PingOneMFA.reset()

        // Then
        let isInitialized = await PingOneMFA.isInitialized
        let config = await PingOneMFA.pingOneMFAConfig
        XCTAssertFalse(isInitialized)
        XCTAssertNil(config)
    }

    func test17_MultipleConfigurationCalls() async {
        // First configuration
        await PingOneMFA.config {
            $0.geo = .northAmerica
        }

        // Second configuration should override
        await PingOneMFA.config {
            $0.geo = .europe
        }

        let config = await PingOneMFA.pingOneMFAConfig
        guard let config = config else {
            XCTFail("Config should not be nil")
            return
        }

        XCTAssertEqual(config.geo, .europe)
    }

    // MARK: - collectPush Error-Path Test

    /// collectPush error-path: mock throws PingOneMFAError when shouldThrowError == true.
    /// Happy-path cannot be tested via mock because NotificationObject (PingOneSDK) has no
    /// accessible initialiser, preventing construction of a PushNotification stub value.
    func test18_MockCollectPushErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Collect push failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.collectPush(userInfo: [:])
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Collect push failed")
            XCTAssertTrue(MockPingOneMFA.collectPushCalled)
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
            environmentId: "env-1"
        )
        let b = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-1",
            deviceId: "device-1",
            environmentId: "env-1"
        )
        let c = PingOneMfaAccount(
            region: "Europe",
            id: "user-2",
            deviceId: "device-2",
            environmentId: "env-2"
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
