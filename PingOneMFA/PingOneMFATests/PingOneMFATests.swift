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

    func test04_InitDoesNotReinitializeIfAlreadyInitialized() async throws {
        let counter = CallCounter()

        // First call — configure runs once
        try await PingOneMFA.initializeIfNeeded {
            await counter.increment()
        }
        await XCTAssertEqualAsync(await counter.value, 1)

        // Second call — isInitialized is true, configure must be skipped
        try await PingOneMFA.initializeIfNeeded {
            await counter.increment()
        }
        await XCTAssertEqualAsync(await counter.value, 1)
    }

    func test05_ConcurrentInitializeCallsShareSingleConfigure() async throws {
        let probe = ConfigureProbe()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<2 {
                group.addTask {
                    try await PingOneMFA.initializeIfNeeded {
                        try await probe.configure()
                    }
                }
            }

            _ = await waitForConfigureCallCount(minimum: 1, probe: probe)

            for _ in 0..<50 {
                await Task.yield()
            }

            let callCount = await probe.callCount
            XCTAssertEqual(callCount, 1)

            await probe.completeAll()
            try await group.waitForAll()
        }

        let isInitialized = await PingOneMFA.isInitialized
        XCTAssertTrue(isInitialized)
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
            family: "User"
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
        let payload = try await MockPingOneMFA.generateMobilePayload()

        // Then
        XCTAssertTrue(MockPingOneMFA.generateMobilePayloadCalled)
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

    // MARK: - processRemoteNotification Tests

    /// test18: SDK handles the notification internally — no PushNotification returned.
    func test18_MockProcessRemoteNotificationReturnsNilWhenSDKHandlesInternally() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        MockPingOneMFA.processRemoteNotificationReturnValue = nil

        // When
        let result = try await MockPingOneMFA.processRemoteNotification(userInfo: [:])

        // Then
        XCTAssertTrue(MockPingOneMFA.processRemoteNotificationCalled)
        XCTAssertNil(result)
    }

    /// test18b: error-path — mock throws PingOneMFAError when shouldThrowError == true.
    /// Happy-path (non-nil PushNotification) cannot be tested because NotificationObject
    /// (PingOneSDK) has no accessible initialiser.
    func test18b_MockProcessRemoteNotificationErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Collect push failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.processRemoteNotification(userInfo: [:])
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Collect push failed")
            XCTAssertTrue(MockPingOneMFA.processRemoteNotificationCalled)
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

    func test20b_DeviceInfoResultExposesAccountsAndErrors() {
        let account = PingOneMfaAccount(
            region: "NorthAmerica",
            id: "user-1",
            deviceId: "device-1",
            environmentId: "env-1",
            name: "Test",
            family: "User"
        )
        let diagnosticError = PingOneMFAError("diagnostic")

        let result = PingOneMFADeviceInfo(accounts: [account], errors: [diagnosticError])

        XCTAssertEqual(result.accounts, [account])
        XCTAssertEqual(result.errors?.first?.message, "diagnostic")
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

    // MARK: - processRemoteNotificationAction Mock Tests

    /// test22: verifies that MockPingOneMFA.processRemoteNotificationAction returns nil when the
    /// SDK handles the action internally (no PushNotification needed).
    /// Happy-path (non-nil return) cannot be tested because NotificationObject (PingOneSDK)
    /// has no accessible initialiser, preventing construction of a PushNotification stub value.
    func test22_MockProcessRemoteNotificationActionReturnsNilWhenSDKHandlesInternally() async throws {
        // Given
        MockPingOneMFA.shouldThrowError = false
        MockPingOneMFA.processRemoteNotificationActionReturnValue = nil

        // When
        let result = try await MockPingOneMFA.processRemoteNotificationAction(
            identifier: "notification.confirm",
            authenticationMethod: "user",
            userInfo: [:]
        )

        // Then
        XCTAssertTrue(MockPingOneMFA.processRemoteNotificationActionCalled)
        XCTAssertNil(result)
        XCTAssertEqual(MockPingOneMFA.lastActionIdentifier, "notification.confirm")
        XCTAssertEqual(MockPingOneMFA.lastActionAuthenticationMethod, "user")
    }

    /// test23: verifies that MockPingOneMFA.processRemoteNotificationAction throws a PingOneMFAError
    /// when shouldThrowError is set, exercising the error path.
    func test23_MockProcessRemoteNotificationActionErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Process notification action failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.processRemoteNotificationAction(
                identifier: "notification.deny",
                authenticationMethod: "user",
                userInfo: [:]
            )
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Process notification action failed")
            XCTAssertTrue(MockPingOneMFA.processRemoteNotificationActionCalled)
            XCTAssertEqual(MockPingOneMFA.lastActionIdentifier, "notification.deny")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - parseAPNSAlert Tests

    func test24_ParseAPNSAlert_DictAlert_ReturnsTitleAndBody() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Auth Request", "body": "Approve login?"]]
        ]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertEqual(title, "Auth Request")
        XCTAssertEqual(message, "Approve login?")
    }

    func test25_ParseAPNSAlert_StringAlert_ReturnsNilTitleAndStringMessage() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "You have a new login request"]
        ]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertNil(title)
        XCTAssertEqual(message, "You have a new login request")
    }

    func test26_ParseAPNSAlert_MissingAlert_ReturnsBothNil() {
        let userInfo: [AnyHashable: Any] = ["aps": [:]]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertNil(title)
        XCTAssertNil(message)
    }

    func test27_ParseAPNSAlert_MissingAps_ReturnsBothNil() {
        let userInfo: [AnyHashable: Any] = ["custom": "value"]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertNil(title)
        XCTAssertNil(message)
    }

    func test28_ParseAPNSAlert_DictAlertMissingBody_ReturnsNilMessage() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Auth Request"]]
        ]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertEqual(title, "Auth Request")
        XCTAssertNil(message)
    }

    func test29_ParseAPNSAlert_DictAlertMissingTitle_ReturnsNilTitle() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["body": "Approve login?"]]
        ]
        let (title, message) = PingOneMFA.parseAPNSAlert(from: userInfo)
        XCTAssertNil(title)
        XCTAssertEqual(message, "Approve login?")
    }

    func test30_ParseAPNSAlert_EmptyUserInfo_ReturnsBothNil() {
        let (title, message) = PingOneMFA.parseAPNSAlert(from: [:])
        XCTAssertNil(title)
        XCTAssertNil(message)
    }

    private func waitForConfigureCallCount(minimum: Int, probe: ConfigureProbe) async -> Int {
        var latestCount = await probe.callCount
        var attempts = 0

        while latestCount < minimum && attempts < 100 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            latestCount = await probe.callCount
            attempts += 1
        }

        return latestCount
    }
}

private func XCTAssertEqualAsync<T: Equatable>(
    _ expression1: @autoclosure () async throws -> T,
    _ expression2: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let lhs = try await expression1()
        let rhs = try await expression2()
        XCTAssertEqual(lhs, rhs, file: file, line: line)
    } catch {
        XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}

private actor CallCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor ConfigureProbe {
    private(set) var callCount = 0
    private var continuations: [CheckedContinuation<Void, any Error>] = []

    func configure() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            callCount += 1
            continuations.append(continuation)
        }
    }

    func completeAll(error: Error? = nil) {
        let pendingContinuations = continuations
        continuations.removeAll()
        pendingContinuations.forEach { continuation in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }
}
