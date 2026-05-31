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

    public var errorDescription: String? { message }

    init(_ error: Error) {
        let nsError = error as NSError
        let userInfo = nsError.userInfo
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        self.message = "Code=\(nsError.code) \"\(nsError.localizedDescription)\" UserInfo={\(userInfo)}"
    }

    init(_ message: String = "Unknown error") {
        self.message = message
    }
}
