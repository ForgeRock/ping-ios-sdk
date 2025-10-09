//
//  OathError.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Errors that can occur during OATH operations.
///
/// `OathError` provides comprehensive error handling for all OATH-related operations,
/// including credential management, URI parsing, code generation, and policy enforcement.
/// Each error case includes detailed information to help developers diagnose and resolve issues.
///
/// ## Error Categories
///
/// - **Credential Management**: Errors related to storing, retrieving, and managing credentials
/// - **URI Parsing**: Errors that occur when parsing otpauth:// or mfauth:// URIs
/// - **Authentication**: Errors during OTP code generation and validation
/// - **Policy**: Errors related to policy enforcement and credential locking
/// - **System**: General system and initialization errors
///
/// ## Usage Examples
///
/// ```swift
/// do {
///     let credential = try await client.addCredentialFromUri(uri)
///     let code = try await client.generateCode(credential.id)
/// } catch let error as OathError {
///     switch error {
///     case .invalidUri(let message):
///         print("Invalid URI format: \(message)")
///         // Show user-friendly error about QR code format
///     case .credentialLocked(let id):
///         print("Credential is locked: \(id)")
///         // Prompt user for authentication or wait for unlock
///     case .codeGenerationFailed(let message, let underlying):
///         print("Code generation failed: \(message)")
///         // Check device time or credential validity
///     default:
///         print("OATH error: \(error.localizedDescription)")
///     }
/// }
/// ```
///
/// ## Error Recovery
///
/// Many errors provide recovery suggestions through the `recoverySuggestion` property:
///
/// ```swift
/// if let suggestion = error.recoverySuggestion {
///     print("Suggestion: \(suggestion)")
/// }
/// ```
public enum OathError: LocalizedError, Sendable {

    // MARK: - Credential Management Errors

    /// The credential was not found.
    case credentialNotFound(String)

    /// The credential is locked and cannot be used.
    case credentialLocked(String)

    /// A credential with the same ID already exists.
    case duplicateCredential(String)

    
    // MARK: - URI Parsing Errors

    /// The provided URI is invalid or malformed.
    case invalidUri(String)

    /// A required parameter is missing from the URI.
    case missingRequiredParameter(String)

    /// A parameter value is invalid.
    case invalidParameterValue(String)

    /// Failed to format the credential as a URI.
    case uriFormatting(String)

    
    // MARK: - Authentication Errors

    /// The secret key is invalid or corrupted.
    case invalidSecret(String)

    /// The OATH type string is not recognized.
    case invalidOathType(String)

    /// The algorithm string is not supported.
    case invalidAlgorithm(String)

    /// Code generation failed due to cryptographic errors.
    case codeGenerationFailed(String, Error? = nil)

    
    // MARK: - Policy Errors

    /// A policy violation occurred.
    case policyViolation(String, String)

    
    // MARK: - System Errors

    /// Client initialization failed.
    case initializationFailed(String, Error? = nil)

    /// Cleanup operations failed.
    case cleanupFailed(String, Error? = nil)

    
    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .credentialNotFound(let id):
            return "Credential with ID '\(id)' was not found"
        case .credentialLocked(let id):
            return "Credential with ID '\(id)' is locked and cannot be used"
        case .duplicateCredential(let id):
            return "A credential with ID '\(id)' already exists"
        case .invalidUri(let message):
            return "Invalid URI: \(message)"
        case .missingRequiredParameter(let message):
            return "Missing required parameter: \(message)"
        case .invalidParameterValue(let message):
            return "Invalid parameter value: \(message)"
        case .uriFormatting(let message):
            return "URI formatting failed: \(message)"
        case .invalidSecret(let message):
            return "Invalid secret key: \(message)"
        case .invalidOathType(let type):
            return "Invalid OATH type: \(type)"
        case .invalidAlgorithm(let algorithm):
            return "Unsupported algorithm: \(algorithm)"
        case .codeGenerationFailed(let message, _):
            return "Code generation failed: \(message)"
        case .policyViolation(let policy, let message):
            return "Policy '\(policy)' violation: \(message)"
        case .initializationFailed(let message, _):
            return "Initialization failed: \(message)"
        case .cleanupFailed(let message, _):
            return "Cleanup failed: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .credentialNotFound(_):
            return "The requested credential does not exist in storage"
        case .credentialLocked(_):
            return "The credential is locked by a policy and cannot generate codes"
        case .duplicateCredential(_):
            return "Cannot store credential because one with the same ID already exists"
        case .invalidUri(_):
            return "The URI format is not valid or is not supported"
        case .missingRequiredParameter(_):
            return "A required parameter is missing from the URI"
        case .invalidParameterValue(_):
            return "One or more parameter values are invalid"
        case .uriFormatting(_):
            return "Failed to convert the credential to a URI format"
        case .invalidSecret(_):
            return "The secret key is not valid Base32 data"
        case .invalidOathType(_):
            return "The OATH type is not supported"
        case .invalidAlgorithm(_):
            return "The HMAC algorithm is not supported"
        case .codeGenerationFailed(_, _):
            return "An error occurred during OTP code generation"
        case .policyViolation(_, _):
            return "The operation violates a configured policy"
        case .initializationFailed(_, _):
            return "Failed to initialize the OATH client"
        case .cleanupFailed(_, _):
            return "Failed to clean up resources"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .credentialNotFound(_):
            return "Verify the credential ID is correct or check if the credential exists"
        case .credentialLocked(_):
            return "Check the credential policies or wait for the lock to expire"
        case .duplicateCredential(_):
            return "Use a different credential ID or update the existing credential"
        case .invalidUri(_):
            return "Ensure the URI follows the otpauth:// or mfauth:// format"
        case .missingRequiredParameter(_):
            return "Add the missing parameter to the URI"
        case .invalidParameterValue(_):
            return "Check that all parameter values are within valid ranges"
        case .uriFormatting(_):
            return "Verify the credential data is complete and valid"
        case .invalidSecret(_):
            return "Ensure the secret key is valid Base32 encoded data"
        case .invalidOathType(_):
            return "Use 'totp' or 'hotp' as the OATH type"
        case .invalidAlgorithm(_):
            return "Use SHA1, SHA256, or SHA512 as the algorithm"
        case .codeGenerationFailed(_, _):
            return "Check that the credential data is valid and the device time is correct"
        case .policyViolation(_, _):
            return "Review the policy configuration or contact your administrator"
        case .initializationFailed(_, _):
            return "Check the configuration and try again"
        case .cleanupFailed(_, _):
            return "The client may not be properly cleaned up, but it's safe to continue"
        }
    }
}

/// Storage-specific errors for OATH operations.
///
/// `OathStorageError` handles errors that occur at the storage layer, including
/// iOS Keychain operations, file system access, and data persistence issues.
/// These errors are typically system-related and may require different handling
/// than application-level `OathError` cases.
///
/// ## Common Scenarios
///
/// - **Device Lock**: Keychain access denied when device is locked
/// - **Storage Full**: Insufficient space for storing credentials
/// - **Corruption**: Data corruption in stored credentials
/// - **Permissions**: App permissions insufficient for storage access
///
/// ## Usage Examples
///
/// ```swift
/// do {
///     let credentials = try await storage.getAllOathCredentials()
/// } catch let error as OathStorageError {
///     switch error {
///     case .accessDenied(let message):
///         // Device may be locked or permissions missing
///         print("Storage access denied: \(message)")
///     case .storageCorrupted(let message):
///         // May need to clear and reinitialize storage
///         print("Storage corrupted: \(message)")
///     case .storageFailure(let message, let underlying):
///         // General storage error with potential underlying cause
///         print("Storage failure: \(message)")
///         if let underlying = underlying {
///             print("Underlying error: \(underlying)")
///         }
///     default:
///         print("Storage error: \(error.localizedDescription)")
///     }
/// }
/// ```
public enum OathStorageError: LocalizedError, Sendable {

    /// A general storage operation failed.
    case storageFailure(String, Error? = nil)

    /// A credential with the same ID already exists.
    case duplicateCredential(String)

    /// The storage is corrupted or in an invalid state.
    case storageCorrupted(String)

    /// Access to the storage was denied.
    case accessDenied(String)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .storageFailure(let message, _):
            return "Storage operation failed: \(message)"
        case .duplicateCredential(let id):
            return "Duplicate credential: \(id)"
        case .storageCorrupted(let message):
            return "Storage corrupted: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .storageFailure(_, _):
            return "The underlying storage system encountered an error"
        case .duplicateCredential(_):
            return "A credential with the same identifier already exists"
        case .storageCorrupted(_):
            return "The storage data is corrupted or in an invalid format"
        case .accessDenied(_):
            return "Access to the storage was denied by the system"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .storageFailure(_, _):
            return "Try the operation again or check storage permissions"
        case .duplicateCredential(_):
            return "Use a different credential ID or update the existing credential"
        case .storageCorrupted(_):
            return "Clear the storage and re-add credentials"
        case .accessDenied(_):
            return "Check app permissions or device unlock status"
        }
    }
}
