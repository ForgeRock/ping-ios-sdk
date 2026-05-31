//
//  DeviceFlowStatus.swift
//  PingOidc
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents the status of an RFC 8628 device authorization flow.
public enum DeviceFlowStatus: Sendable {
    /// The device authorization request succeeded. The associated value carries the server response
    /// including the `userCode` and `verificationUri` to display to the end user.
    case started(DeviceAuthorizationResponse)
    /// The polling loop is active. Carries the current poll count, current interval (seconds),
    /// and the `Date` at which the next poll will be attempted.
    case polling(pollCount: Int, pollInterval: Int, nextPollAt: Date)
    /// Authorization succeeded. The associated value is the authenticated `User`.
    case success(any User)
    /// The device code has expired before the user authorized the request.
    case expired
    /// The user denied the authorization request.
    case accessDenied
    /// A terminal error occurred that does not map to a specific RFC 8628 error code.
    case failure(any Error)
}
