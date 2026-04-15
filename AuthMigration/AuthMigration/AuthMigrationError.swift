//
//  AuthMigrationError.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Errors that can occur during the authenticator data migration pipeline.
///
/// `AuthMigrationError` covers the full lifecycle of the migration process, from reading
/// legacy Keychain data through decryption, deserialization, storage writes, and cleanup.
///
/// Each case preserves the underlying system error where applicable, enabling callers to
/// inspect the root cause (e.g., Keychain `OSStatus` codes, `NSKeyedUnarchiver` failures).
///
/// ## Error Flow
///
/// Errors are emitted via ``MigrationProgress/error(step:underlyingError:)`` in the
/// migration `AsyncStream`. The ``MigrationStep`` identifies which pipeline stage failed:
///
/// ```swift
/// case .error(let step, let error):
///     if let migrationError = error as? AuthMigrationError {
///         switch migrationError {
///         case .noLegacyDataFound:
///             // Expected on clean installs — not a real error
///         case .failedToDecryptLegacyData(let inner):
///             logger.e("Decryption failed: \(inner)")
///         default:
///             logger.e("Migration error: \(migrationError)")
///         }
///     }
/// ```
///
/// - SeeAlso: ``AuthMigration``
/// - SeeAlso: `MigrationProgress`
public enum AuthMigrationError: LocalizedError, Sendable {

    /// No legacy authenticator data was found in the Keychain.
    ///
    /// This occurs when the legacy `FRAuthenticator` Keychain services contain no entries,
    /// indicating either a clean install or a previously completed migration.
    case noLegacyDataFound

    /// Failed to read legacy data from the Keychain.
    ///
    /// Wraps the underlying `Error` from `Security.framework` Keychain operations
    /// (e.g., `errSecItemNotFound`, `errSecAuthFailed`).
    ///
    /// - Parameter error: The underlying system error from the Keychain query.
    case failedToReadLegacyData(Error)

    /// Failed to decrypt legacy Keychain data using the Secure Enclave key.
    ///
    /// This occurs when the legacy `SecuredKey` exists but decryption fails, typically
    /// because the device's Secure Enclave state has changed or the key is inaccessible.
    ///
    /// - Parameter error: The underlying `Error` from `SecKeyCreateDecryptedData`.
    case failedToDecryptLegacyData(Error)

    /// Failed to deserialize legacy `NSKeyedArchiver` data.
    ///
    /// This occurs when `NSKeyedUnarchiver` cannot decode the archived object, typically
    /// due to unexpected class names or corrupted archive data.
    ///
    /// - Parameter message: A description of the deserialization failure.
    case failedToDeserializeLegacyData(String)

    /// Failed to save migrated OATH credentials to the new storage.
    ///
    /// Wraps the underlying `Error` from ``OathStorage/storeOathCredential(_:)``.
    ///
    /// - Parameter error: The underlying storage error.
    case failedToSaveOathCredentials(Error)

    /// Failed to save migrated Push credentials to the new storage.
    ///
    /// Wraps the underlying `Error` from ``PushStorage/storePushCredential(_:)``.
    ///
    /// - Parameter error: The underlying storage error.
    case failedToSavePushCredentials(Error)

    /// Failed to clean up legacy Keychain data after migration.
    ///
    /// Cleanup failures are **non-critical** — credentials have already been migrated
    /// successfully. The legacy data will remain in the Keychain but will not interfere
    /// with the new storage.
    ///
    /// - Parameter error: The underlying system error from the Keychain delete operation.
    case failedToCleanupLegacyData(Error)

    /// A human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case .noLegacyDataFound:
            return "No legacy authenticator data found in Keychain"
        case .failedToReadLegacyData(let error):
            return "Failed to read legacy Keychain data: \(error.localizedDescription)"
        case .failedToDecryptLegacyData(let error):
            return "Failed to decrypt legacy data: \(error.localizedDescription)"
        case .failedToDeserializeLegacyData(let message):
            return "Failed to deserialize legacy data: \(message)"
        case .failedToSaveOathCredentials(let error):
            return "Failed to save OATH credentials: \(error.localizedDescription)"
        case .failedToSavePushCredentials(let error):
            return "Failed to save Push credentials: \(error.localizedDescription)"
        case .failedToCleanupLegacyData(let error):
            return "Failed to cleanup legacy data: \(error.localizedDescription)"
        }
    }
}
