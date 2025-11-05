//
//  OathKeychainErrorHandler.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import LocalAuthentication
import PingLogger

/// Enhanced error handling for keychain operations.
/// Provides detailed error mapping and recovery suggestions.
internal enum OathKeychainErrorHandler {

    /// Maps keychain error codes to OathStorageError with enhanced context.
    /// - Parameters:
    ///   - status: The keychain operation status code.
    ///   - operation: Description of the operation that failed.
    ///   - account: The keychain account involved (for logging).
    ///   - logger: Optional logger for detailed error reporting.
    /// - Returns: Appropriate OathStorageError with recovery information.
    static func mapKeychainError(
        _ status: OSStatus,
        operation: String,
        account: String? = nil,
        logger: Logger? = nil
    ) -> OathStorageError {

        let accountInfo = account.map { " for account '\($0)'" } ?? ""
        let context = "\(operation)\(accountInfo)"

        logger?.e("Keychain operation failed: \(context), status: \(status)", error: nil)

        switch status {
        case errSecSuccess:
            return .storageFailure("Unexpected success status in error handler")

        // Item-related errors
        case errSecItemNotFound:
            return .storageFailure("Item not found: \(context)")

        case errSecDuplicateItem:
            return .duplicateCredential("Duplicate item: \(context)")

        // Access and authentication errors
        case errSecNotAvailable:
            logger?.e("Keychain not available - device may be locked or keychain corrupted", error: nil)
            return .accessDenied("Keychain service not available")

        case errSecAuthFailed:
            logger?.e("Keychain authentication failed - incorrect credentials or access denied", error: nil)
            return .accessDenied("Authentication failed for keychain access")

        case errSecUserCanceled:
            logger?.w("User cancelled keychain operation", error: nil)
            return .accessDenied("User cancelled authentication")

        case errSecInteractionNotAllowed:
            logger?.e("Keychain interaction not allowed - app may be in background or Touch ID/Face ID disabled", error: nil)
            return .accessDenied("User interaction not allowed for keychain access")

        case errSecMissingEntitlement:
            logger?.e("Missing keychain entitlements - check app configuration", error: nil)
            return .accessDenied("Missing keychain access entitlements")

        // Data integrity errors
        case errSecDecode:
            logger?.e("Failed to decode keychain data - may be corrupted", error: nil)
            return .storageCorrupted("Keychain data corrupted or invalid format")

        case errSecDataNotAvailable:
            logger?.e("Keychain data not available", error: nil)
            return .storageCorrupted("Keychain data not available")

        case errSecDataTooLarge:
            logger?.e("Keychain data too large", error: nil)
            return .storageFailure("Data too large for keychain storage")

        // Memory and resource errors
        case errSecAllocate:
            logger?.e("Memory allocation failed during keychain operation", error: nil)
            return .storageFailure("Memory allocation failed")

        case errSecParam:
            logger?.e("Invalid parameter passed to keychain operation", error: nil)
            return .storageFailure("Invalid keychain operation parameters")

        case errSecBadReq:
            logger?.e("Invalid keychain request", error: nil)
            return .storageFailure("Invalid keychain request")

        // Biometric authentication errors
        case OSStatus(LAError.passcodeNotSet.rawValue):
            logger?.e("Device passcode not set - required for secure keychain access", error: nil)
            return .accessDenied("Device passcode required")

        // iOS-specific Touch ID/Face ID errors
        case OSStatus(LAError.biometryNotAvailable.rawValue):
            logger?.e("Touch ID/Face ID not available", error: nil)
            return .accessDenied("Biometric authentication not available")

        case OSStatus(LAError.biometryNotEnrolled.rawValue):
            logger?.e("Touch ID/Face ID not enrolled", error: nil)
            return .accessDenied("Biometric authentication not enrolled")

        case OSStatus(LAError.biometryLockout.rawValue):
            logger?.e("Touch ID/Face ID locked out", error: nil)
            return .accessDenied("Biometric authentication locked out")

        // General errors
        case errSecUnimplemented:
            logger?.e("Keychain function not implemented", error: nil)
            return .storageFailure("Keychain function not available")

        case errSecIO:
            logger?.e("Keychain I/O error", error: nil)
            return .storageFailure("Keychain I/O error")

        case errSecOpWr:
            logger?.e("Keychain file already open with write permission", error: nil)
            return .storageFailure("Keychain write conflict")

        default:
            logger?.e("Unknown keychain error: \(status)", error: nil)
            return .storageFailure("Keychain operation failed with status: \(status)")
        }
    }

    /// Determines if a keychain error is recoverable.
    /// - Parameter error: The OathStorageError to check.
    /// - Returns: true if the operation might succeed if retried.
    static func isRecoverableError(_ error: OathStorageError) -> Bool {
        switch error {
        case .storageFailure(let message, _):
            // Temporary issues that might resolve
            return message.contains("not available") ||
                   message.contains("I/O error") ||
                   message.contains("allocation failed")

        case .accessDenied(let message):
            // User interaction issues that might be resolved
            return message.contains("User cancelled") ||
                   message.contains("interaction not allowed")

        case .duplicateCredential, .storageCorrupted:
            // These require explicit handling, not retries
            return false
        }
    }

    /// Provides user-friendly error messages for common keychain issues.
    /// - Parameter error: The OathStorageError to explain.
    /// - Returns: User-friendly explanation and suggested actions.
    static func userFriendlyErrorInfo(_ error: OathStorageError) -> (title: String, message: String, suggestions: [String]) {
        switch error {
        case .accessDenied(let message):
            if message.contains("Biometric") {
                return (
                    title: "Biometric Authentication Required",
                    message: "This credential requires Face ID or Touch ID to access.",
                    suggestions: [
                        "Ensure Face ID or Touch ID is enabled in device settings",
                        "Try again and authenticate when prompted",
                        "Check that your biometric data is enrolled"
                    ]
                )
            } else if message.contains("passcode") {
                return (
                    title: "Device Passcode Required",
                    message: "A device passcode is required to access secure credentials.",
                    suggestions: [
                        "Set a device passcode in Settings",
                        "Ensure the device is unlocked",
                        "Try again after unlocking the device"
                    ]
                )
            } else {
                return (
                    title: "Access Denied",
                    message: "Unable to access secure storage.",
                    suggestions: [
                        "Unlock your device and try again",
                        "Check app permissions in device settings",
                        "Restart the app if the problem persists"
                    ]
                )
            }

        case .storageCorrupted(let message):
            return (
                title: "Storage Corrupted",
                message: "The credential storage appears to be corrupted.",
                suggestions: [
                    "Clear all credentials and re-add them",
                    "Restart the app and try again",
                    "Contact support if the problem persists"
                ]
            )

        case .duplicateCredential(let credentialId):
            return (
                title: "Duplicate Credential",
                message: "A credential with this identifier already exists.",
                suggestions: [
                    "Use a different credential name",
                    "Remove the existing credential first",
                    "Update the existing credential instead"
                ]
            )

        case .storageFailure(let message, _):
            if message.contains("not available") {
                return (
                    title: "Storage Unavailable",
                    message: "Secure storage is temporarily unavailable.",
                    suggestions: [
                        "Ensure your device is unlocked",
                        "Try again in a few moments",
                        "Restart the app if the problem persists"
                    ]
                )
            } else {
                return (
                    title: "Storage Error",
                    message: "An error occurred while accessing secure storage.",
                    suggestions: [
                        "Try the operation again",
                        "Restart the app if the problem persists",
                        "Contact support for assistance"
                    ]
                )
            }
        }
    }

    /// Logs detailed error information for debugging.
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - context: Additional context about the operation.
    ///   - logger: Logger for output.
    static func logDetailedError(_ error: Error, context: String, logger: Logger?) {
        logger?.e("=== OATH Keychain Error Details ===", error: nil)
        logger?.e("Context: \(context)", error: nil)
        logger?.e("Error: \(error)", error: error)

        if let storageError = error as? OathStorageError {
            let info = userFriendlyErrorInfo(storageError)
            logger?.e("User-friendly title: \(info.title)", error: nil)
            logger?.e("User-friendly message: \(info.message)", error: nil)
            logger?.e("Suggestions: \(info.suggestions.joined(separator: ", "))", error: nil)
            logger?.e("Recoverable: \(isRecoverableError(storageError))", error: nil)
        }

        if let nsError = error as NSError? {
            logger?.e("Domain: \(nsError.domain)", error: nil)
            logger?.e("Code: \(nsError.code)", error: nil)
            logger?.e("User Info: \(nsError.userInfo)", error: nil)
        }

        logger?.e("=== End Error Details ===", error: nil)
    }
}
