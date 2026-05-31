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

/// Represents a registered PingOne MFA account on this device.
public struct PingOneMfaAccount: Sendable, Equatable {
    /// The cloud region where this account is registered (e.g. `"NA"`, `"EU"`).
    public let region: String
    /// The unique identifier for this account.
    public let id: String
    /// The identifier of the device this account is bound to.
    public let deviceId: String
    /// The PingOne environment this account belongs to.
    public let environmentId: String
    /// The display name of the account.
    public var name: String
    /// The account family / application name shown to the user.
    public var family: String

    /// Creates a `PingOneMfaAccount` with all required fields.
    ///
    /// - Parameters:
    ///   - region: The cloud region for this account.
    ///   - id: The unique account identifier.
    ///   - deviceId: The device identifier this account is bound to.
    ///   - environmentId: The PingOne environment identifier.
    ///   - name: The display name of the account.
    ///   - family: The account family / application name.
    public init(region: String, id: String, deviceId: String, environmentId: String, name: String, family: String) {
        self.region = region
        self.id = id
        self.deviceId = deviceId
        self.environmentId = environmentId
        self.name = name
        self.family = family
    }
}
