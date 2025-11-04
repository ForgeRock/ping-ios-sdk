//
//  PushError.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Errors that can occur during Push operations.
///
/// `PushError` provides comprehensive error handling for all Push-related operations,
/// including credential management, URI parsing, notification processing, and policy enforcement.
/// Each error case includes detailed information to help developers diagnose and resolve issues.
///
/// ## Error Categories
///
/// - **Initialization**: Errors during client initialization
/// - **Credential Management**: Errors related to storing, retrieving, and managing credentials
/// - **URI Parsing**: Errors that occur when parsing pushauth:// or mfauth:// URIs
/// - **Notification Processing**: Errors during push notification handling
/// - **Policy**: Errors related to policy enforcement and credential locking
/// - **Network**: Errors during communication with the server
/// - **Storage**: Errors related to persistent storage operations
///
/// ## Usage Examples
///
/// ```swift
/// do {
///     let credential = try await client.addCredentialFromUri(uri)
///     let notification = try await client.processNotification(userInfo)
/// } catch let error as PushError {
///     switch error {
///     case .invalidUri(let message):
///         print("Invalid URI format: \(message)")
///         // Show user-friendly error about QR code format
///     case .credentialLocked(let id):
///         print("Credential is locked: \(id)")
///         // Prompt user for authentication or wait for unlock
///     case .networkFailure(let message, _):
///         print("Network error: \(message)")
///         // Retry or show offline message
///     default:
///         print("Push error: \(error.localizedDescription)")
///     }
/// }
/// ```
public enum PushError: Error, LocalizedError, Sendable {
    
    // MARK: - Initialization Errors
    
    /// The Push client has not been initialized.
    case notInitialized
    
    /// Initialization of the Push client failed.
    case initializationFailed(String, Error?)
    
    // MARK: - URI Parsing Errors
    
    /// The provided URI is invalid or malformed.
    case invalidUri(String)
    
    /// A required parameter is missing from the URI.
    case missingRequiredParameter(String)
    
    /// A parameter value is invalid or malformed.
    case invalidParameterValue(String)
    
    /// URI formatting failed during credential export.
    case uriFormatting(String)
    
    // MARK: - Type and Platform Errors
    
    /// The push type is invalid or not supported.
    case invalidPushType(String)
    
    /// The platform is invalid or not supported.
    case invalidPlatform(String)
    
    // MARK: - Storage Errors
    
    /// A storage operation failed.
    case storageFailure(String, Error?)
    
    // MARK: - Device Token Errors
    
    /// The device token has not been set.
    case deviceTokenNotSet
    
    // MARK: - Handler Errors
    
    /// No push handler is available for the specified platform.
    case noHandlerForPlatform(String)
    
    /// Message parsing failed.
    case messageParsingFailed(String)
    
    // MARK: - Credential Errors
    
    /// The specified credential was not found.
    case credentialNotFound(String)
    
    /// The credential is locked due to policy violation.
    case credentialLocked(String)
    
    // MARK: - Notification Errors
    
    /// The specified notification was not found.
    case notificationNotFound(String)
    
    // MARK: - Policy Errors
    
    /// A policy violation occurred.
    case policyViolation(String)
    
    // MARK: - Registration Errors
    
    /// Registration with the server failed.
    case registrationFailed(String)
    
    // MARK: - Network Errors
    
    /// A network operation failed.
    case networkFailure(String, Error?)
    
    // MARK: - LocalizedError Conformance
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Push client has not been initialized"
            
        case .initializationFailed(let message, let underlyingError):
            if let underlyingError = underlyingError {
                return "Initialization failed: \(message) - \(underlyingError.localizedDescription)"
            }
            return "Initialization failed: \(message)"
            
        case .invalidUri(let message):
            return "Invalid Push URI: \(message)"
            
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
            
        case .invalidParameterValue(let message):
            return "Invalid parameter value: \(message)"
            
        case .uriFormatting(let message):
            return "URI formatting failed: \(message)"
            
        case .invalidPushType(let type):
            return "Invalid push type: \(type)"
            
        case .invalidPlatform(let platform):
            return "Invalid platform: \(platform)"
            
        case .storageFailure(let message, let underlyingError):
            if let underlyingError = underlyingError {
                return "Storage failure: \(message) - \(underlyingError.localizedDescription)"
            }
            return "Storage failure: \(message)"
            
        case .deviceTokenNotSet:
            return "Device token has not been set"
            
        case .noHandlerForPlatform(let platform):
            return "No handler available for platform: \(platform)"
            
        case .messageParsingFailed(let message):
            return "Message parsing failed: \(message)"
            
        case .credentialNotFound(let id):
            return "Credential not found: \(id)"
            
        case .credentialLocked(let id):
            return "Credential is locked: \(id)"
            
        case .notificationNotFound(let id):
            return "Notification not found: \(id)"
            
        case .policyViolation(let message):
            return "Policy violation: \(message)"
            
        case .registrationFailed(let message):
            return "Registration failed: \(message)"
            
        case .networkFailure(let message, let underlyingError):
            if let underlyingError = underlyingError {
                return "Network failure: \(message) - \(underlyingError.localizedDescription)"
            }
            return "Network failure: \(message)"
        }
    }
}

/// Errors specific to Push storage operations.
///
/// These errors are thrown by storage implementations when persistence operations fail.
public enum PushStorageError: Error, LocalizedError, Sendable {
    
    /// A storage operation failed.
    case storageFailure(String, Error?)
    
    /// Attempted to store a credential with a duplicate ID.
    case duplicateCredential(String)
    
    /// Attempted to store a notification with a duplicate ID.
    case duplicateNotification(String)
    
    public var errorDescription: String? {
        switch self {
        case .storageFailure(let message, let underlyingError):
            if let underlyingError = underlyingError {
                return "Storage failure: \(message) - \(underlyingError.localizedDescription)"
            }
            return "Storage failure: \(message)"
            
        case .duplicateCredential(let id):
            return "Duplicate credential: \(id)"
            
        case .duplicateNotification(let id):
            return "Duplicate notification: \(id)"
        }
    }
}
