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

/// Custom error type for PingOneMFA SDK exceptions.
///
/// When an operation fails with one or more native SDK errors, ``internalErrorsList`` contains
/// structured representations of each error — useful for logging and diagnostics.
///
/// ### Usage
/// ```swift
/// do {
///     try await PingOneMFA.setDeviceToken(deviceToken)
/// } catch let error as PingOneMFAError {
///     print(error.message)
///     error.internalErrorsList?.forEach { e in
///         print("code=\(e.code) message=\(e.message)")
///     }
/// }
/// ```
public struct PingOneMFAError: Error, LocalizedError, Sendable {
    /// Human-readable description of the failure.
    public let message: String

    /// Structured list of individual SDK errors, or `nil` when the failure did not originate
    /// from the native SDK (e.g. an unexpected exception).
    public let internalErrorsList: [PingOneMFAInternalError]?

    /// The error text exposed via `LocalizedError`, equal to ``message``.
    public var errorDescription: String? { message }

    init(_ error: Error) {
        if let existing = error as? PingOneMFAError {
            self = existing
            return
        }
        let nsError = error as NSError
        let userInfoString = nsError.userInfo
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        self.message = "Code=\(nsError.code) \(nsError.localizedDescription)"
        self.internalErrorsList = [PingOneMFAInternalError(
            code: nsError.code,
            message: nsError.localizedDescription,
            userInfo: nsError.userInfo.compactMapValues { "\($0)" }
        )]
    }

    init(_ message: String = "Unknown error") {
        self.message = message
        self.internalErrorsList = nil
    }

    /// Creates an error aggregating multiple native SDK errors.
    /// - Parameter errors: The array of native `NSError` values returned by the upstream SDK.
    init(errors: [Error]) {
        let mapped = errors.map { e -> PingOneMFAInternalError in
            let ns = e as NSError
            return PingOneMFAInternalError(
                code: ns.code,
                message: ns.localizedDescription,
                userInfo: ns.userInfo.compactMapValues { "\($0)" }
            )
        }
        let joined = mapped.map(\.message).joined(separator: "; ")
        self.message = joined.isEmpty ? "Unknown error" : joined
        self.internalErrorsList = mapped
    }
}
