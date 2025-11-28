//
//  NetworkError.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Common network error cases surfaced by PingNetwork operations.
public enum NetworkError: LocalizedError, Sendable {
    case invalidRequest(String)
    case invalidResponse(String)
    case timeout
    case networkUnavailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .timeout:
            return "Request timed out."
        case .networkUnavailable:
            return "Network unavailable."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}
