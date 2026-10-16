//
//  PushType.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Describes the interaction model required by a PingOne MFA push notification.
public enum PushType: Sendable {
    /// A standard authentication request. The user approves or denies with a single tap.
    case `default`

    /// A  test push sent by the server to verify the device's push registration.
    /// No user action is required.
    case dry

    /// A number-matching challenge. Use `getNumbersChallenge` to retrieve the options;
    /// an empty array means free-form digit entry is expected.
    case challenge
}
