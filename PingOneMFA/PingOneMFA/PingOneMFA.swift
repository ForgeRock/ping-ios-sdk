//
//  PingOneMFA.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.

import Foundation
import UserNotifications
import PingOneSDK

/// Actor to manage PingOneMFA SDK state with thread safety
@globalActor
public actor PingOneMFAActor {
    public static let shared = PingOneMFAActor()
}

/// The `PingOneMFA` class provides methods to initialize the SDK and interact with the PingOne MFA service.
@PingOneMFAActor
public class PingOneMFA {
    internal private(set) static var isInitialized: Bool = false

    /// Initializes the PingOneMFA SDK with the provided geographic region.
    /// This method should be called before using any other methods in the PingOneMFA SDK.
    /// This method is idempotent — if already initialized, it returns immediately.
    ///
    /// - Parameter geo: The geographic region for the PingOneMFA SDK.
    /// - Throws: `PingOneMFAError` if initialization fails.
    public nonisolated static func initialize(geo: Geo) async throws {
        if await isInitialized {
            return
        }

        let pingOneGeo: PingOneGeo
        switch geo {
        case .northAmerica:
            pingOneGeo = .NorthAmerica
        case .europe:
            pingOneGeo = .Europe
        case .australia:
            pingOneGeo = .Australia
        case .canada:
            pingOneGeo = .Canada
        case .singapore:
            pingOneGeo = .Singapore
        }

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.configure(geo: pingOneGeo) { error in
                Task { @PingOneMFAActor in
                    if let error = error {
                        self.isInitialized = false
                        continuation.resume(throwing: PingOneMFAError(error))
                    } else {
                        self.isInitialized = true
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Registers the device's APNS push token with the PingOne MFA service.
    ///
    /// Uses `.sandbox` token type in `DEBUG` builds and `.production` otherwise.
    ///
    /// - Parameter pushToken: The raw APNS device token `Data` received in
    ///   `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// - Throws: `PingOneMFAError` containing all errors reported by the upstream SDK
    ///   if at least one error is present.
    public nonisolated static func setDeviceToken(_ pushToken: Data) async throws {
        #if DEBUG
        let tokenType = PingOne.APNSDeviceTokenType.sandbox
        #else
        let tokenType = PingOne.APNSDeviceTokenType.production
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.setDeviceToken(token: pushToken, type: tokenType) { errors in
                if let errors = errors, !errors.isEmpty {
                    continuation.resume(throwing: PingOneMFAError(errors: errors))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Pairs this device with a PingOne environment using the provided pairing key.
    ///
    /// - Parameter pairingKey: The pairing key string provided by the PingOne environment.
    /// - Throws: `PingOneMFAError` if pairing fails.
    public nonisolated static func pair(pairingKey: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PingOne.pair(pairingKey) { _, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Returns all registered MFA accounts for this device, along with any non-fatal
    /// diagnostic errors reported by the upstream SDK.
    ///
    /// - Returns: A tuple `(accounts, errors)` where `accounts` is the parsed
    ///   `PingOneMfaAccount` array and `errors` is `nil` if the SDK reported no errors,
    ///   otherwise an array of `PingOneMFAError` values carrying diagnostic detail.
    /// - Throws: `PingOneMFAError` when the SDK returns no data and at least one real error,
    ///   or when the SDK returns neither data nor errors.
    public nonisolated static func getDeviceInfo() async throws -> (accounts: [PingOneMfaAccount], errors: [PingOneMFAError]?) {
        return try await withCheckedThrowingContinuation { continuation in
            PingOne.getInfo(completion: { deviceInfo, errors in
                if let deviceInfo, !deviceInfo.isEmpty {
                    // Data available — return it along with any diagnostic errors from the SDK.
                    let accounts = AccountParser.parse(deviceInfo)
                    let mappedErrors = errors?.map { PingOneMFAError($0) }
                    continuation.resume(returning: (accounts, mappedErrors))
                } else if let errors, !errors.isEmpty {
                    // No data and at least one real error — treat as failure.
                    continuation.resume(throwing: PingOneMFAError(errors: errors))
                } else {
                    // Neither data nor errors — SDK misbehaved; avoid hanging the continuation.
                    continuation.resume(throwing: PingOneMFAError("getDeviceInfo failed: no error details provided"))
                }
            })
        }
    }

    /// Returns the current one-time passcode and its remaining validity window.
    ///
    /// `secondsRemaining` is computed as `Int(validUntil - now)` where `validUntil`
    /// is the epoch-seconds timestamp returned by the upstream SDK.
    ///
    /// - Returns: An `OtpCodeInfo` containing the current passcode and seconds remaining.
    /// - Throws: `PingOneMFAError` if the SDK call fails or returns no passcode info.
    public nonisolated static func getOneTimePasscode() async throws -> OtpCodeInfo {
        return try await withCheckedThrowingContinuation { continuation in
            PingOne.getOneTimePasscode { passcodeInfo, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else if let passcodeInfo = passcodeInfo {
                    let now = Date().timeIntervalSince1970
                    let secondsRemaining = Int(passcodeInfo.validUntil - now)
                    continuation.resume(returning: OtpCodeInfo(
                        code: passcodeInfo.passcode,
                        secondsRemaining: secondsRemaining
                    ))
                } else {
                    continuation.resume(throwing: PingOneMFAError())
                }
            }
        }
    }

    /// Processes an incoming APNS push notification for MFA authentication.
    ///
    /// Extracts the `title` and `message` from `userInfo["aps"]["alert"]` (handling
    /// both the string-alert and dict-alert forms of the APNS payload).
    ///
    /// - Parameter userInfo: The raw `userInfo` dictionary from
    ///   `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
    /// - Returns: A `PushNotification` holding the upstream `NotificationObject` plus
    ///   the parsed title and message.
    /// - Throws: `PingOneMFAError` if the SDK call fails or returns no notification object.
    public nonisolated static func processRemoteNotification(userInfo: [AnyHashable: Any]) async throws -> PushNotification {
        let (title, message) = parseAPNSAlert(from: userInfo)

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.processRemoteNotification(userInfo) { notificationObject, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else if let notificationObject = notificationObject {
                    continuation.resume(returning: PushNotification(
                        notificationObject: notificationObject,
                        title: title,
                        message: message
                    ))
                } else {
                    continuation.resume(throwing: PingOneMFAError())
                }
            }
        }
    }

    /// Processes a user action taken on an APNS banner notification (e.g., approve or deny tap).
    ///
    /// Extracts the `title` and `message` from `userInfo["aps"]["alert"]` and wraps
    /// `PingOne.processRemoteNotificationAction(_:authenticationMethod:forRemoteNotification:completionHandler:)`.
    ///
    /// - Parameters:
    ///   - identifier: The action identifier from the notification response
    ///     (e.g., `"notification.confirm"` or `"notification.deny"`).
    ///   - authenticationMethod: The authentication method string (e.g., `"user"`).
    ///   - userInfo: The raw `userInfo` dictionary from the notification response.
    /// - Returns: A `PushNotification` when the SDK requires the app to present approve/deny UI,
    ///   or `nil` when the SDK handled the action internally.
    /// - Throws: `PingOneMFAError` if the SDK reports an error.
    public nonisolated static func processRemoteNotificationAction(
        identifier: String,
        authenticationMethod: String?,
        userInfo: [AnyHashable: Any]
    ) async throws -> PushNotification? {
        let (title, message) = parseAPNSAlert(from: userInfo)

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.processRemoteNotificationAction(
                identifier,
                authenticationMethod: authenticationMethod,
                forRemoteNotification: userInfo
            ) { notificationObject, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else if let notificationObject = notificationObject {
                    continuation.resume(returning: PushNotification(
                        notificationObject: notificationObject,
                        title: title,
                        message: message
                    ))
                } else {
                    // SDK handled the action internally; no UI needed
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Generates a mobile payload for use in PingOne authentication flows.
    ///
    /// - Returns: The mobile payload string.
    /// - Throws: `PingOneMFAError` if payload generation fails or returns no payload.
    public nonisolated static func generateMobilePayload() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PingOne.generateMobilePayload(completionHandler: { payload, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else if let payload = payload {
                    continuation.resume(returning: payload)
                } else {
                    continuation.resume(throwing: PingOneMFAError())
                }
            })
        }
    }

    /// Returns the set of `UNNotificationCategory` objects registered by the PingOneSDK.
    ///
    /// Call this at app launch to register PingOneMFA's notification categories with
    /// `UNUserNotificationCenter` so that actionable banner notifications can be delivered.
    ///
    /// - Returns: The `Set<UNNotificationCategory>` provided by the binary PingOneSDK.
    public nonisolated static func getNotificationCategories() -> Set<UNNotificationCategory> {
        return PingOne.getUNNotificationCategories() as Set<UNNotificationCategory>
    }

    /// Resets the SDK to uninitialized state (useful for testing)
    internal static func reset() {
        isInitialized = false
    }

     /// Parses the `title` and `message` from an APNS `userInfo` payload.
    ///
    /// Handles both the dict-alert form (`aps.alert` is `[String: Any]`) and the
    /// string-alert form (`aps.alert` is `String`).
    ///
    /// - Parameter userInfo: The raw APNS `userInfo` dictionary.
    /// - Returns: A tuple of `(title: String?, message: String?)`.
    private nonisolated static func parseAPNSAlert(from userInfo: [AnyHashable: Any]) -> (title: String?, message: String?) {
        guard let aps = userInfo["aps"] as? [String: Any] else {
            return (title: nil, message: nil)
        }
        if let alert = aps["alert"] as? [String: Any] {
            return (title: alert["title"] as? String, message: alert["body"] as? String)
        } else if let alertString = aps["alert"] as? String {
            return (title: nil, message: alertString)
        } else {
            return (title: nil, message: nil)
        }
    }

}
