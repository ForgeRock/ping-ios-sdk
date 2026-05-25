//
//  PingOneMfaAccount.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A value type representing a registered MFA account.
public struct PingOneMfaAccount: Sendable, Equatable {
    /// The geographic region of the account (top-level key in the deviceInfo response).
    public let region: String
    /// The user identifier.
    public let id: String
    /// The device identifier (`device.id` in the response).
    public let deviceId: String
    /// The environment identifier (`environment.id` in the response).
    public let environmentId: String

    /// Initializes a new instance of `PingOneMfaAccount`.
    public init(region: String, id: String, deviceId: String, environmentId: String) {
        self.region = region
        self.id = id
        self.deviceId = deviceId
        self.environmentId = environmentId
    }
}
