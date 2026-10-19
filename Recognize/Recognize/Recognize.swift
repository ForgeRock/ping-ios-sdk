//
//  Recognize.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Custom error type for Recognize SDK exceptions.
///
/// `code` and `name` carry the shared cross-platform error model (the same codes and
/// names the web Recognize SDK exposes, e.g. `CORE_USER_NOT_ENROLLED` / 3003), so
/// integrators can branch on one common logic across platforms. `message` keeps the
/// human-readable text, and `sdkCode` preserves the native Keyless SDK code for
/// debugging.
public struct RecognizeError: Error, LocalizedError, Sendable {
    /// The human-readable error message.
    public let message: String

    /// The shared cross-platform error code, identical to the one the web Recognize SDK uses
    /// for the same error. Errors raised entirely on-device, before any Keyless SDK call, use
    /// `SDK_ERROR` (1000).
    public let code: Int

    /// The shared cross-platform error name (e.g. `"CORE_USER_NOT_ENROLLED"`). The SDK always
    /// sets it; it is `nil` only for an error created without one.
    public let name: String?

    /// The native Keyless SDK error code, or `nil` when the error never reached the
    /// Keyless SDK.
    public let sdkCode: Int?

    /// Diagnostic information forwarded from the underlying `KeylessSDKError`, if any
    /// (e.g. `flowId`, `sessionId`, `underlyingError`, `stacktrace`).
    public let debuggingInfo: [String: String]

    /// A localized description of the error.
    public var errorDescription: String? {
        return message
    }

    public init(
        _ message: String,
        code: Int,
        name: String? = nil,
        sdkCode: Int? = nil,
        debuggingInfo: [String: String] = [:]
    ) {
        self.message = message
        self.code = code
        self.name = name
        self.sdkCode = sdkCode
        self.debuggingInfo = debuggingInfo
    }
}
