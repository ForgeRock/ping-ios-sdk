//
//  PingOneMFAError.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Custom error type for PingOneMFA SDK exceptions
public struct PingOneMFAError: Error, LocalizedError, Sendable {
    public let message: String

    /// A localized description of the error.
    public var errorDescription: String? {
        return message
    }

    /// Initializes a new instance of `PingOneMFAError` with a given message.
    public init(_ message: String) {
        self.message = message
    }
}
