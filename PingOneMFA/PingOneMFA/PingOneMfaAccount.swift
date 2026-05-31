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

/// Represents a PingOne MFA account.
public struct PingOneMfaAccount: Sendable, Equatable {
    public let region: String
    public let id: String
    public let deviceId: String
    public let environmentId: String
    public var name: String
    public var family: String


    /// Initializes a new instance of `PingOneMfaAccount`.
    public init(region: String, id: String, deviceId: String, environmentId: String, name: String, family: String) {
        self.region = region
        self.id = id
        self.deviceId = deviceId
        self.environmentId = environmentId
        self.name = name
        self.family = family
    }
}
