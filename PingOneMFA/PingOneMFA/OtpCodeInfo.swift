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
    public let code: String
    public let secondsRemaining: Int

    public init(code: String, secondsRemaining: Int) {
        self.code = code
        self.secondsRemaining = secondsRemaining
    }
}
