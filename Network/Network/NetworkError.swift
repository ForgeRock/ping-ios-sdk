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
    /// The request could not be constructed or is malformed.
    case invalidRequest(String)
    
    /// The response could not be parsed or is malformed.
    case invalidResponse(String)
    
    /// The request exceeded the configured timeout interval.
    case timeout
    
    /// The network is unreachable or connection was lost.
    case networkUnavailable
    
    /// The request was explicitly cancelled.
    case cancelled

    /// Provides a localized description of the error.
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

