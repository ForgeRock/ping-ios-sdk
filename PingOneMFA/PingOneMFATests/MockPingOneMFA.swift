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
    private static let lock = NSLock()
    nonisolated(unsafe) static var shouldThrowError = false
    nonisolated(unsafe) static var errorMessage = "Operation failed"
    nonisolated(unsafe) static var initializeCalled = false
    nonisolated(unsafe) static var initializeCallCount = 0
    nonisolated(unsafe) static var registerPushTokenCalled = false
    nonisolated(unsafe) static var pairCalled = false
    nonisolated(unsafe) static var getDeviceInfoCalled = false
    nonisolated(unsafe) static var getOneTimePasscodeCalled = false
    nonisolated(unsafe) static var processRemoteNotificationCalled = false
    nonisolated(unsafe) static var generateMobilePayloadCalled = false
    nonisolated(unsafe) static var lastGeo: Geo?

    // Return values for happy-path tests
    nonisolated(unsafe) static var accountsReturnValue: [PingOneMfaAccount] = []
    nonisolated(unsafe) static var otpReturnValue = OtpCodeInfo(code: "123456", secondsRemaining: 30)
    nonisolated(unsafe) static var mobilePayloadReturnValue = "mockMobilePayload"
    // processRemoteNotification cannot return a real PushNotification in tests because
    // NotificationObject (from PingOneSDK) has no accessible initializer. The mock supports
    // the nil-return path (SDK handles internally) and the error path.
    nonisolated(unsafe) static var processRemoteNotificationReturnValue: PushNotification? = nil

    // getNotificationCategories tracking state
    nonisolated(unsafe) static var getNotificationCategoriesCalled = false
    nonisolated(unsafe) static var notificationCategoriesReturnValue: Set<UNNotificationCategory> = []

    // processRemoteNotificationAction tracking state
    nonisolated(unsafe) static var processRemoteNotificationActionCalled = false
    // processRemoteNotificationAction cannot return a real PushNotification in tests because
    // NotificationObject (from PingOneSDK) has no accessible initialiser. The mock therefore
    // only supports the nil-return and error paths for processRemoteNotificationAction.
    nonisolated(unsafe) static var processRemoteNotificationActionReturnValue: PushNotification? = nil
    nonisolated(unsafe) static var lastActionIdentifier: String? = nil
    nonisolated(unsafe) static var lastActionAuthenticationMethod: String? = nil

    static func reset() {
        shouldThrowError = false
        errorMessage = "Operation failed"
        initializeCalled = false
        initializeCallCount = 0
        registerPushTokenCalled = false
        pairCalled = false
        getDeviceInfoCalled = false
        getOneTimePasscodeCalled = false
        processRemoteNotificationCalled = false
        generateMobilePayloadCalled = false
        lastGeo = nil
        accountsReturnValue = []
        otpReturnValue = OtpCodeInfo(code: "123456", secondsRemaining: 30)
        mobilePayloadReturnValue = "mockMobilePayload"
        processRemoteNotificationReturnValue = nil
        getNotificationCategoriesCalled = false
        notificationCategoriesReturnValue = []
        processRemoteNotificationActionCalled = false
        processRemoteNotificationActionReturnValue = nil
        lastActionIdentifier = nil
        lastActionAuthenticationMethod = nil
    }

    static func initialize(geo: Geo) async throws {
        lock.withLock {
            initializeCalled = true
            initializeCallCount += 1
            lastGeo = geo
        }
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
    }

    static func setDeviceToken(_ pushToken: Data) async throws {
        registerPushTokenCalled = true
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

    static func getDeviceInfo() async throws -> PingOneMFADeviceInfo {
        getDeviceInfoCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return PingOneMFADeviceInfo(accounts: accountsReturnValue)
    }

    static func getOneTimePasscode() async throws -> OtpCodeInfo {
        getOneTimePasscodeCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return otpReturnValue
    }

    static func processRemoteNotification(userInfo: [AnyHashable: Any]) async throws -> PushNotification? {
        processRemoteNotificationCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return processRemoteNotificationReturnValue
    }

    static func generateMobilePayload() async throws -> String {
        generateMobilePayloadCalled = true
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return mobilePayloadReturnValue
    }

    static func getNotificationCategories() -> Set<UNNotificationCategory> {
        getNotificationCategoriesCalled = true
        return notificationCategoriesReturnValue
    }

    static func processRemoteNotificationAction(
        identifier: String,
        authenticationMethod: String?,
        userInfo: [AnyHashable: Any]
    ) async throws -> PushNotification? {
        processRemoteNotificationActionCalled = true
        lastActionIdentifier = identifier
        lastActionAuthenticationMethod = authenticationMethod
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return processRemoteNotificationActionReturnValue
    }
}
