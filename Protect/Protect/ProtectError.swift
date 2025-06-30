// 
//  ProtectError.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Custom error type for Protect SDK exceptions
public struct ProtectError: Error, LocalizedError {
    public let message: String

    /// A localized description of the error.
    public var errorDescription: String? {
        return message
    }

    /// Initializes a new instance of `ProtectError` with a given message.
    public init(_ message: String) {
        self.message = message
    }
}
