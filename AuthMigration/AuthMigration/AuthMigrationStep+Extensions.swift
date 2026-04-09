//
//  AuthMigrationStep+Extensions.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingCommons

/// Migration step constants for the authenticator migration pipeline.
///
/// These steps correspond to the three sequential phases of the authenticator migration:
/// 1. Import legacy Keychain data
/// 2. Convert and store credentials in new OATH/Push storage
/// 3. Clean up legacy Keychain entries
///
/// - SeeAlso: ``AuthMigration``
/// - SeeAlso: `MigrationProgress`
extension MigrationStep {

    /// Imports legacy authenticator data from the `FRAuthenticator` Keychain services.
    ///
    /// This step reads all accounts and mechanisms from the four legacy Keychain service
    /// identifiers, optionally decrypts them using the legacy Secure Enclave key, and
    /// deserializes the `NSKeyedArchiver` payloads into intermediate data models.
    public static let importLegacyData = MigrationStep(id: "importLegacyData", description: "Import legacy data")

    /// Converts legacy mechanisms to new credential formats and stores them.
    ///
    /// This step maps legacy OATH (TOTP/HOTP) mechanisms to ``OathCredential`` and
    /// legacy Push mechanisms to ``PushCredential``, then persists them via the configured
    /// ``OathStorage`` and ``PushStorage`` implementations. Duplicate credentials
    /// (matching issuer + accountName) are skipped. Individual credential failures do not
    /// abort the step.
    public static let migrateCredentials = MigrationStep(id: "migrateCredentials", description: "Migrate credentials")

    /// Cleans up legacy Keychain data after successful migration.
    ///
    /// This step deletes all entries from the four legacy `FRAuthenticator` Keychain services
    /// (accounts, mechanisms, notifications, device tokens). Cleanup failures are logged as
    /// warnings but do not cause the migration to fail.
    public static let cleanup = MigrationStep(id: "cleanup", description: "Cleanup legacy data")
}
