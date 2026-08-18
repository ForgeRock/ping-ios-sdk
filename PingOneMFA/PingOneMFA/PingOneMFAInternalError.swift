//
//  PingOneMFAInternalError.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Structured representation of a single PingOne SDK error.
///
/// Instances are produced from the native SDK error type and exposed through
/// ``PingOneMFAError/internalErrorsList``.
///
/// - SeeAlso: ``PingOneMFAError``
public struct PingOneMFAInternalError: Sendable, Equatable {
    /// Numeric error code returned by the PingOne MFA native SDK.
    public let code: Int
    /// Human-readable error message returned by the native SDK.
    public let message: String
    /// Additional diagnostic key/value pairs returned by the server.
    /// May be empty if the server did not include additional context.
    public let userInfo: [String: String]
}
