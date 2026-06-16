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
    /// The current OTP code string to display to the user.
    public let code: String
    /// The number of seconds remaining before this code expires, or zero if already expired.
    public let secondsRemaining: Int

    /// Creates an `OtpCodeInfo` with the given code and remaining validity.
    ///
    /// - Parameters:
    ///   - code: The current OTP code string.
    ///   - secondsRemaining: Seconds until the code expires, or zero if already expired.
    public init(code: String, secondsRemaining: Int) {
        self.code = code
        self.secondsRemaining = secondsRemaining
    }
}
