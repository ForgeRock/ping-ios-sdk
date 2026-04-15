//
//  AuthMigration.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingCommons
import PingLogger
import PingOath
import PingPush

/// Entry point for FR Authenticator data migration.
///
/// `AuthMigration` orchestrates the three-step pipeline that imports legacy `FRAuthenticator`
/// Keychain data, converts it to the new OATH and Push credential storage format, and
/// optionally cleans up the legacy Keychain entries.
///
/// ### Migration Pipeline
///
/// 1. **Import** — Reads accounts and mechanisms from the legacy `FRAuthenticator` Keychain
///    services. If data is encrypted with a Secure Enclave key, it is decrypted automatically.
/// 2. **Migrate** — Converts legacy mechanisms to ``OathCredential`` (TOTP/HOTP) and
///    ``PushCredential`` (Push), then stores them via the configured storage implementations.
///    Duplicate credentials (matching issuer + accountName) are skipped.
/// 3. **Cleanup** — Deletes all entries from the four legacy Keychain services (accounts,
///    mechanisms, notifications, device tokens). Cleanup failures are logged as warnings
///    but do not cause the migration to fail.
///
/// The migration is **idempotent**: if no legacy data is found, the pipeline completes
/// immediately. A private actor ensures that concurrent calls do not execute the pipeline
/// simultaneously.
///
/// ### Usage
///
/// **Fire-and-forget** (typically at app startup):
///
/// ```swift
/// import PingAuthMigration
///
/// Task {
///     await AuthMigration.migrateIfNeeded()
/// }
/// ```
///
/// **With progress tracking:**
///
/// ```swift
/// import PingAuthMigration
/// import PingCommons
///
/// Task {
///     let stream = AuthMigration.start { config in
///         config.logger = LogManager.logger
///     }
///
///     for await progress in stream {
///         switch progress {
///         case .started:
///             showLoadingIndicator()
///         case .inProgress(let step, let current, let total):
///             updateProgress("Step \(current)/\(total): \(step)")
///         case .stepCompleted(let step):
///             logger.i("Completed: \(step)")
///         case .success(let message):
///             hideLoadingIndicator()
///             logger.i(message)
///         case .error(let step, let error):
///             hideLoadingIndicator()
///             logger.e("Migration failed at \(step): \(error)")
///         }
///     }
/// }
/// ```
///
/// - SeeAlso: ``AuthMigrationConfig``
/// - SeeAlso: ``AuthMigrationError``
/// - SeeAlso: `MigrationProgress`
/// - SeeAlso: `MigrationStep`
public final class AuthMigration: @unchecked Sendable {

    /// Private actor to ensure mutual exclusion of migration runs.
    private static let stateManager = MigrationStateManager()

    /// Total number of steps in the migration pipeline.
    private static let totalSteps = 3

    // MARK: - Public API

    /// Executes the full migration pipeline and returns an `AsyncStream` of progress events.
    ///
    /// The stream emits ``MigrationProgress`` values as the pipeline advances through
    /// its steps. The stream completes naturally after emitting either
    /// ``MigrationProgress/success(message:)`` or ``MigrationProgress/error(step:underlyingError:)``.
    ///
    /// Callers must iterate the stream (e.g., via `for await`) for the migration to execute.
    /// The ``migrateIfNeeded(configure:)`` convenience method is available for callers who
    /// don't need granular progress updates.
    ///
    /// - Parameter configure: A closure to configure ``AuthMigrationConfig``. All properties
    ///   use their default values if no closure is provided, which is suitable for standard
    ///   `FRAuthenticator` installations using the default `KeychainServiceClient`.
    /// - Returns: An `AsyncStream<MigrationProgress>` that emits migration lifecycle events.
    ///
    /// ## Example — default migration
    ///
    /// ```swift
    /// let stream = AuthMigration.start()
    /// for await progress in stream {
    ///     // handle progress
    /// }
    /// ```
    ///
    /// ## Example — custom configuration
    ///
    /// ```swift
    /// let stream = AuthMigration.start { config in
    ///     config.accessGroup = "com.myapp.shared"
    ///     config.logger = LogManager.logger
    ///     config.cleanupLegacyData = false
    /// }
    /// ```
    public static func start(
        configure: (AuthMigrationConfig) -> Void = { _ in }
    ) -> AsyncStream<MigrationProgress> {
        let config = AuthMigrationConfig()
        configure(config)

        return AsyncStream { continuation in
            Task {
                let didRun = await stateManager.run {
                    return await executePipeline(config: config, continuation: continuation)
                }
                if !didRun {
                    continuation.finish()
                }
            }
        }
    }

    /// Checks if legacy authenticator data exists without performing migration.
    ///
    /// This is a lightweight, non-destructive check that queries the legacy Keychain services
    /// for the existence of account or mechanism entries.
    ///
    /// - Parameter accessGroup: The Keychain access group used by the legacy SDK, or `nil` for the default.
    /// - Returns: `true` if legacy data exists; `false` otherwise.
    public static func isMigrationNeeded(
        accessGroup: String? = nil
    ) async -> Bool {
        let reader = LegacyKeychainReader(accessGroup: accessGroup)
        return reader.legacyDataExists()
    }

    /// Convenience: runs migration and awaits completion, ignoring individual progress events.
    ///
    /// Does not throw if no legacy data is found — returns `false` instead.
    /// This is the recommended entry point for apps that don't need progress tracking.
    ///
    /// - Parameter configure: A closure to configure ``AuthMigrationConfig``.
    /// - Returns: `true` if migration was performed; `false` if no legacy data was found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Task {
    ///     let didMigrate = await AuthMigration.migrateIfNeeded()
    ///     if didMigrate {
    ///         logger.i("Migration completed successfully")
    ///     }
    /// }
    /// ```
    @discardableResult
    public static func migrateIfNeeded(
        configure: (AuthMigrationConfig) -> Void = { _ in }
    ) async -> Bool {
        var migrated = false
        let stream = start(configure: configure)
        for await progress in stream {
            if case .success = progress {
                migrated = true
            }
        }
        return migrated
    }

    // MARK: - Internal Pipeline

    /// Executes the 3-step migration pipeline.
    /// - Returns: `true` if the pipeline completed successfully; `false` on error or no data.
    private static func executePipeline(
        config: AuthMigrationConfig,
        continuation: AsyncStream<MigrationProgress>.Continuation
    ) async -> Bool {
        let logger = config.logger

        continuation.yield(.started)

        // Step 1: Import Legacy Data
        continuation.yield(.inProgress(step: .importLegacyData, current: 1, total: totalSteps))
        logger?.i("Step 1/\(totalSteps): Importing legacy data")

        let reader = LegacyKeychainReader(accessGroup: config.accessGroup, logger: logger)

        guard reader.legacyDataExists() else {
            logger?.i("No legacy data found — migration not needed")
            continuation.yield(.error(step: .importLegacyData, underlyingError: AuthMigrationError.noLegacyDataFound))
            continuation.finish()
            return false
        }

        let accounts: [LegacyAccountArchive]
        let mechanisms: [LegacyMechanismArchive]

        do {
            accounts = try reader.getAllAccounts()
            mechanisms = try reader.getAllMechanisms()
        } catch {
            logger?.e("Failed to read legacy data: \(error)", error: error)
            continuation.yield(.error(step: .importLegacyData, underlyingError: error))
            continuation.finish()
            return false
        }

        if mechanisms.isEmpty {
            logger?.i("No mechanisms found in legacy data — migration not needed")
            continuation.yield(.error(step: .importLegacyData, underlyingError: AuthMigrationError.noLegacyDataFound))
            continuation.finish()
            return false
        }

        logger?.i("Found \(accounts.count) accounts and \(mechanisms.count) mechanisms")

        // Build account lookup: "issuer-accountName" → LegacyAccountArchive
        let accountLookup = Dictionary(
            accounts.map { ("\($0.issuer)-\($0.accountName)", $0) },
            uniquingKeysWith: { first, _ in first }
        )

        continuation.yield(.stepCompleted(step: .importLegacyData))

        // Step 2: Migrate Credentials
        continuation.yield(.inProgress(step: .migrateCredentials, current: 2, total: totalSteps))
        logger?.i("Step 2/\(totalSteps): Migrating credentials")

        let oathStorage = config.oathStorage ?? OathKeychainStorage()
        let pushStorage = config.pushStorage ?? PushKeychainStorage()

        var oathCount = 0
        var pushCount = 0

        for mechanism in mechanisms {
            let accountKey = "\(mechanism.issuer)-\(mechanism.accountName)"
            guard let account = accountLookup[accountKey] else {
                logger?.w("No account found for mechanism \(accountKey) — skipping", error: nil)
                continue
            }

            let mechanismType = mechanism.type.lowercased()

            switch mechanismType {
            case "totp", "hotp":
                do {
                    // Duplicate check
                    let existing = try await oathStorage.getCredentialByIssuerAndAccount(
                        issuer: account.issuer,
                        accountName: account.accountName
                    )
                    if existing != nil {
                        logger?.i("OATH credential already exists for \(accountKey) — skipping")
                        continue
                    }

                    let credential = LegacyDataConverter.toOathCredential(
                        mechanism: mechanism,
                        account: account
                    )
                    try await oathStorage.storeOathCredential(credential)
                    oathCount += 1
                    logger?.d("Migrated OATH credential: \(credential.issuer) - \(credential.accountName)")
                } catch {
                    logger?.e("Failed to migrate OATH credential \(accountKey): \(error)", error: error)
                }

            case "push":
                do {
                    // Duplicate check
                    let existing = try await pushStorage.getCredentialByIssuerAndAccount(
                        issuer: account.issuer,
                        accountName: account.accountName
                    )
                    if existing != nil {
                        logger?.i("Push credential already exists for \(accountKey) — skipping")
                        continue
                    }

                    let credential = LegacyDataConverter.toPushCredential(
                        mechanism: mechanism,
                        account: account
                    )
                    try await pushStorage.storePushCredential(credential)
                    pushCount += 1
                    logger?.d("Migrated Push credential: \(credential.issuer) - \(credential.accountName)")
                } catch {
                    logger?.e("Failed to migrate Push credential \(accountKey): \(error)", error: error)
                }

            default:
                logger?.w("Unknown mechanism type: \(mechanism.type) — skipping", error: nil)
            }
        }

        logger?.i("Migrated \(oathCount) OATH + \(pushCount) Push credentials")
        continuation.yield(.stepCompleted(step: .migrateCredentials))

        // Step 3: Cleanup
        continuation.yield(.inProgress(step: .cleanup, current: 3, total: totalSteps))
        logger?.i("Step 3/\(totalSteps): Cleanup")

        if config.cleanupLegacyData {
            reader.deleteLegacyData()
            logger?.i("Legacy Keychain data deleted")
        } else {
            logger?.i("Cleanup skipped — cleanupLegacyData is false")
        }

        continuation.yield(.stepCompleted(step: .cleanup))

        let message = "Migrated \(oathCount) OATH + \(pushCount) Push credentials"
        continuation.yield(.success(message: message))
        logger?.i("Migration completed: \(message)")
        continuation.finish()
        return true
    }

    // MARK: - Testing Support

    /// Resets the migration state manager. **For testing only.**
    internal static func resetMigrationState() async {
        await stateManager.reset()
    }
}

// MARK: - MigrationStateManager

/// Actor that prevents concurrent migration runs.
///
/// Ensures that only one migration pipeline executes at a time, matching the
/// `Mutex.withLock` pattern used in the Android SDK.
///
/// Guards against Swift actor reentrancy: `isRunning` is set **before** awaiting the body,
/// so a second caller entering during the suspension point is correctly rejected.
private actor MigrationStateManager {

    /// Whether a migration has already completed successfully in this app session.
    private var hasRun = false

    /// Whether a migration is currently executing (guards against actor reentrancy).
    private var isRunning = false

    /// Executes the given closure if migration has not already run and is not currently running.
    /// Only marks `hasRun` on success, allowing retries after failures.
    ///
    /// - Parameter body: The migration pipeline to execute. Returns `true` on success.
    /// - Returns: `true` if the body was executed; `false` if it was skipped.
    func run(_ body: @Sendable () async -> Bool) async -> Bool {
        guard !hasRun, !isRunning else { return false }
        isRunning = true
        let succeeded = await body()
        isRunning = false
        if succeeded {
            hasRun = true
        }
        return true
    }

    /// Resets the migration state. **For testing only.**
    func reset() {
        hasRun = false
        isRunning = false
    }
}
