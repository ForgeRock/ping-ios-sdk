//
//  PushNotification.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOneSDK

public typealias MFAPushNotification = PushNotification

/// A push notification received from PingOne MFA representing an authentication request.
public struct PushNotification: Sendable, Identifiable {
    /// A unique identifier for this notification instance.
    public let id: String = UUID().uuidString
    internal let notificationObject: NotificationObject
    /// The notification title, if provided by the server.
    public let title: String?
    /// The notification body message, if provided by the server.
    public let message: String?

    /// The interaction model required by this notification.
    ///
    /// Use this to determine the UI flow:
    /// - `.dry` — no user interaction needed; the authentication completes silently.
    /// - `.challenge` — present the number-matching challenge from `getNumbersChallenge`.
    /// - `.default` — standard approve/deny prompt.
    public let pushType: PushType
    /// `true` when this notification represents a cancellation of an in-progress authentication.
    public let isCancelAuthentication: Bool

    /// The list of number options presented to the user when `pushType` is `.challenge`.
    /// Returns an empty array when number matching is not enabled.
    public var getNumbersChallenge: [Int] { numberMatchingOptions }
    private let numberMatchingOptions: [Int]

    internal init(notificationObject: NotificationObject, title: String?, message: String?) {
        self.notificationObject = notificationObject
        self.title = title
        self.message = message
        self.isCancelAuthentication = notificationObject.notificationType == .authCanceled
        self.numberMatchingOptions = notificationObject.numberMatchingOptions
        if notificationObject.notificationType == .done {
            self.pushType = .dry
        } else if !notificationObject.numberMatchingType.isEmpty {
            self.pushType = .challenge
        } else {
            self.pushType = .default
        }
    }

    /// Approves the push notification authentication request.
    ///
    /// - Parameters:
    ///   - authMethod: The authentication method to use for approval.
    ///   - numberChallenge: The number matching challenge value, if applicable.
    /// - Throws: `PingOneMFAError` if approval fails or the upstream SDK reports an error.
    public func approveNotification(authMethod: String?, numberChallenge: Int?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let numberMatchingPickedValue: NSNumber? = numberChallenge.map { NSNumber(value: $0) }
            notificationObject.approve(
                withAuthenticationMethod: authMethod,
                numberMatchingPickedValue: numberMatchingPickedValue
            ) { _, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Denies the push notification authentication request.
    ///
    /// - Throws: `PingOneMFAError` if denial fails.
    public func denyNotification() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationObject.deny(reason: .none) { error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

// PingOneSDK's `NotificationObject` is a binary Objective-C type that is not annotated
// `Sendable`. We assert thread-safety here, at the type the assumption is actually about,
// rather than hiding it behind `@unchecked Sendable` on `PushNotification`:
//   - The SDK delivers the object on its own queue and we hand it off serially
//     (process → post over NotificationCenter → user tap), never mutating it concurrently.
//   - `approveNotification`/`denyNotification` are the only members that touch it after init.
// Placing the conformance here means that if a future PingOneSDK marks `NotificationObject`
// as `Sendable`, this becomes a redundant-conformance compiler error and surfaces for review.
extension NotificationObject: @retroactive @unchecked Sendable {}
