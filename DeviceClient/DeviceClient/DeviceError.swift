// 
//  DeviceError.swift
//  DeviceClient
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Errors that can occur during device management operations
public enum DeviceError: LocalizedError, Sendable {
    /// Network error occurred
    case networkError(error: Error)
    
    /// Request failed with status code
    case requestFailed(statusCode: Int, message: String)
    
    /// Invalid URL
    case invalidUrl(url: String)
    
    /// Failed to decode response
    case decodingFailed(error: Error)
    
    /// Failed to encode request
    case encodingFailed(message: String)
    
    /// Invalid response from server
    case invalidResponse(message: String)
    
    /// Missing or invalid SSO token
    case invalidToken(message: String)
    
    /// Missing configuration
    case missingConfiguration(message: String)
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .requestFailed(let statusCode, let message):
            return "Request failed with status \(statusCode): \(message)"
        case .invalidUrl(let url):
            return "Invalid URL: \(url)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed(let message):
            return "Failed to encode request: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .invalidToken(let message):
            return "Invalid token: \(message)"
        case .missingConfiguration(let message):
            return "Missing configuration: \(message)"
        }
    }
    
    /// A localized message describing the reason for the failure.
    public var failureReason: String? {
        switch self {
        case .networkError:
            return "The network request could not be completed."
        case .requestFailed:
            return "The server returned an error response."
        case .invalidUrl:
            return "The URL is malformed or invalid."
        case .decodingFailed:
            return "The response data could not be decoded."
        case .encodingFailed:
            return "The request data could not be encoded."
        case .invalidResponse:
            return "The server response format is invalid."
        case .invalidToken:
            return "The authentication token is missing or invalid."
        case .missingConfiguration:
            return "Required configuration is missing."
        }
    }
    
    /// A localized message describing how to recover from the failure.
    public var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your network connection and try again."
        case .requestFailed(let statusCode, _):
            if statusCode == 401 {
                return "Please authenticate again."
            } else if statusCode == 404 {
                return "The requested resource was not found."
            } else if statusCode >= 500 {
                return "The server encountered an error. Please try again later."
            }
            return "Please try again or contact support."
        case .invalidUrl:
            return "Please verify the server configuration."
        case .decodingFailed:
            return "The response format may have changed. Please update the SDK."
        case .encodingFailed:
            return "Please verify the device data is valid."
        case .invalidResponse:
            return "The server response format may have changed. Please update the SDK."
        case .invalidToken:
            return "Please authenticate again to obtain a valid token."
        case .missingConfiguration:
            return "Please provide the required configuration."
        }
    }
}
