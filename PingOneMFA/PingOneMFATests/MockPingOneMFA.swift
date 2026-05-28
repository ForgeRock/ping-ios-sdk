//
//  MockPingOneMFA.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation
import UserNotifications
@testable import PingOneMFA

class MockPingOneMFA {
    nonisolated(unsafe) static var shouldThrowError = false
    nonisolated(unsafe) static var errorMessage = "Operation failed"
    nonisolated(unsafe) static var initializeCalled = false
    nonisolated(unsafe) static var initializeCallCount = 0
    nonisolated(unsafe) static var registerCalled = false
    nonisolated(unsafe) static var pairCalled = false
    nonisolated(unsafe) static var getAccountsCalled = false
    nonisolated(unsafe) static var collectOtpCalled = false
    nonisolated(unsafe) static var collectPushCalled = false
    nonisolated(unsafe) static var collectMobilePayloadCalled = false
    nonisolated(unsafe) static var lastGeo: PingOneMFAGeo?

    // Return values for happy-path tests
    nonisolated(unsafe) static var accountsReturnValue: [PingOneMfaAccount] = []
    nonisolated(unsafe) static var otpReturnValue = OtpCodeInfo(code: "123456", secondsRemaining: 30)
    nonisolated(unsafe) static var mobilePayloadReturnValue = "mockMobilePayload"
    // collectPush cannot return a real PushNotification in tests because NotificationObject
    // (from PingOneSDK) has no accessible initializer. The mock therefore only supports
    // the error-path for collectPush.
    nonisolated(unsafe) static var collectPushReturnValue: PushNotification? = nil

    // getNotificationCategories tracking state
    nonisolated(unsafe) static var getNotificationCategoriesCalled = false
    nonisolated(unsafe) static var notificationCategoriesReturnValue: Set<UNNotificationCategory> = []

    // processNotificationAction tracking state
    nonisolated(unsafe) static var processNotificationActionCalled = false
    // processNotificationAction cannot return a real PushNotification in tests because
    // NotificationObject (from PingOneSDK) has no accessible initialiser. The mock therefore
    // only supports the nil-return and error paths for processNotificationAction.
    nonisolated(unsafe) static var processNotificationActionReturnValue: PushNotification? = nil
    nonisolated(unsafe) static var lastActionIdentifier: String? = nil
    nonisolated(unsafe) static var lastActionAuthenticationMethod: String? = nil

    static func reset() {
        shouldThrowError = false
        errorMessage = "Operation failed"
        initializeCalled = false
        initializeCallCount = 0
        registerCalled = false
        pairCalled = false
        getAccountsCalled = false
        collectOtpCalled = false
        collectPushCalled = false
        collectMobilePayloadCalled = false
        lastGeo = nil
        accountsReturnValue = []
        otpReturnValue = OtpCodeInfo(code: "123456", secondsRemaining: 30)
        mobilePayloadReturnValue = "mockMobilePayload"
        collectPushReturnValue = nil
        getNotificationCategoriesCalled = false
        notificationCategoriesReturnValue = []
        processNotificationActionCalled = false
        processNotificationActionReturnValue = nil
        lastActionIdentifier = nil
        lastActionAuthenticationMethod = nil
    }

    static func initialize(geo: PingOneMFAGeo) async throws {
        initializeCalled = true
        initializeCallCount += 1
        lastGeo = geo
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
    }

    static func register(pushToken: Data) async throws {
        registerCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
    }

    static func pair(pairingKey: String) async throws {
        pairCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
    }

    static func getAccounts() async throws -> [PingOneMfaAccount] {
        getAccountsCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return accountsReturnValue
    }

    static func collectOtp() async throws -> OtpCodeInfo {
        collectOtpCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return otpReturnValue
    }

    static func collectPush(userInfo: [AnyHashable: Any]) async throws -> PushNotification {
        collectPushCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        // NotificationObject (from PingOneSDK) cannot be instantiated in tests;
        // unwrap the pre-configured return value or throw if not configured.
        guard let value = collectPushReturnValue else {
            throw PingOneMFAError("collectPush: no return value configured")
        }
        return value
    }

    static func collectMobilePayload() async throws -> String {
        collectMobilePayloadCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return mobilePayloadReturnValue
    }

    static func getNotificationCategories() -> Set<UNNotificationCategory> {
        getNotificationCategoriesCalled = true
        return notificationCategoriesReturnValue
    }

    static func processNotificationAction(
        identifier: String,
        authenticationMethod: String?,
        userInfo: [AnyHashable: Any]
    ) async throws -> PushNotification? {
        processNotificationActionCalled = true
        lastActionIdentifier = identifier
        lastActionAuthenticationMethod = authenticationMethod
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return processNotificationActionReturnValue
    }
}
