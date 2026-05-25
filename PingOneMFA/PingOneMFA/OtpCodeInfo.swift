//
//  OtpCodeInfo.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A value type representing a one-time passcode with its validity window.
public struct OtpCodeInfo: Sendable, Equatable {
    /// The one-time passcode string.
    public let code: String
    /// The number of seconds remaining until the passcode expires.
    public let secondsRemaining: Int

    /// Initializes a new instance of `OtpCodeInfo`.
    public init(code: String, secondsRemaining: Int) {
        self.code = code
        self.secondsRemaining = secondsRemaining
    }
}
