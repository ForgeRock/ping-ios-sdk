//
//  BindingMigration.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingStorage

/// Actor to manage migration state in a thread-safe manner
private actor MigrationStateManager {
    var attempted = false
    
    func markAttempted() {
        attempted = true
    }
    
    func isAttempted() -> Bool {
        return attempted
    }
    
    func reset() {
        attempted = false
    }
}

/// Manages the migration of device binding data from the legacy SDK to the new SDK format.
///
/// This class orchestrates a multi-step migration process that transfers user key metadata
/// from the legacy keychain location to the new storage format.
///
/// ## Migration Steps
///
/// The migration executes three sequential steps:
///
/// 1. **Check for Legacy Data**: Verifies if legacy keychain data exists and needs migration
/// 2. **Migrate User Keys**: Transfers user key metadata from legacy keychain to new storage
/// 3. **Cleanup**: Removes legacy keychain data after successful migration
///
/// ## Usage
///
/// Automatic migration (recommended):
/// ```swift
/// // Migration starts automatically when BindingModule is first used
/// // or can be triggered explicitly
/// Task {
///     try await BindingMigration.migrate()
/// }
/// ```
///
/// Manual migration with custom configuration:
/// ```swift
/// Task {
///     try await BindingMigration.migrate(
///         accessGroup: "com.myapp.keychain",
///         logger: myLogger,
///         cleanupLegacyData: true
///     )
/// }
/// ```
///
/// ## Progress Monitoring
///
/// The migration logs progress updates that can be observed through the provided logger:
/// - Migration started
/// - Legacy data check results
/// - Number of keys migrated
/// - Cleanup status
/// - Completion or error details
///
public class BindingMigration {
    
    /// Shared state manager for tracking migration
    private static let stateManager = MigrationStateManager()
    
    private init() {}
    
    /// Executes the device binding migration process.
    ///
    /// This method migrates user key metadata from the legacy keychain location
    /// (`com.forgerock.ios.devicebinding.keychainservice`) to the new storage format.
    /// The migration is idempotent - running it multiple times is safe and will not
    /// duplicate or corrupt data.
    ///
    /// The method performs the following steps:
    /// 1. Checks if migration has already been completed
    /// 2. Verifies if legacy data exists in the keychain
    /// 3. Reads all user keys from the legacy storage
    /// 4. Saves them to the new storage format
    /// 5. Optionally deletes the legacy data
    ///
    /// - Parameters:
    ///   - accessGroup: The keychain access group that was configured in the legacy app, if any.
    ///                  Defaults to `nil` (no access group).
    ///   - logger: Optional logger for debugging and monitoring migration progress.
    ///   - cleanupLegacyData: Whether to delete legacy keychain data after successful migration.
    ///                        Defaults to `true`.
    ///   - storageConfig: Custom storage configuration for the new format. If not provided,
    ///                    uses the default `UserKeyStorageConfig`.
    ///
    /// - Throws: `MigrationError` if migration fails at any step.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await BindingMigration.migrate(
    ///         accessGroup: "com.myapp.shared",
    ///         logger: Logger.standard
    ///     )
    ///     print("Migration completed successfully")
    /// } catch MigrationError.noLegacyDataFound {
    ///     print("No legacy data to migrate")
    /// } catch {
    ///     print("Migration failed: \(error)")
    /// }
    /// ```
    public static func migrate(
        accessGroup: String? = nil,
        logger: Logger? = nil,
        cleanupLegacyData: Bool = true,
        storageConfig: UserKeyStorageConfig? = nil
    ) async throws {
        // Check if migration has already been attempted
        let isAttempted = await stateManager.isAttempted()
        if isAttempted {
            logger?.i("Migration has already been attempted, skipping")
            return
        }
        
        logger?.i("Starting device binding migration")
        
        // Step 1: Check for legacy data
        let legacyStorage = LegacyUserKeysStorage(accessGroup: accessGroup, logger: logger)
        
        let legacyDataExists = await legacyStorage.exists()
        if !legacyDataExists {
            logger?.i("No legacy keychain data found, skipping migration")
            await stateManager.markAttempted()
            throw MigrationError.noLegacyDataFound
        }
        
        logger?.i("Legacy keychain data found, proceeding with migration")
        
        // Step 2: Migrate user keys
        do {
            let legacyKeys = try await legacyStorage.getAllKeys()
            logger?.i("Retrieved \(legacyKeys.count) keys from legacy storage")
            
            if legacyKeys.isEmpty {
                logger?.i("No keys found in legacy storage, skipping migration")
                await stateManager.markAttempted()
                throw MigrationError.noLegacyDataFound
            }
            
            logger?.i("Found \(legacyKeys.count) keys to migrate: \(legacyKeys.map { "\($0.userId)(\($0.authType))" })")
            
            // Save all keys to new storage
            let config = storageConfig ?? UserKeyStorageConfig()
            let userKeysStorage = UserKeysStorage(config: config)
            
            // Check if keys already exist in new storage to avoid duplication
            let existingKeys = try await userKeysStorage.findAll()
            let existingUserIds = Set(existingKeys.map { $0.userId })
            
            var migratedCount = 0
            for legacyKey in legacyKeys {
                if existingUserIds.contains(legacyKey.userId) {
                    logger?.i("Key for user \(legacyKey.userId) already exists in new storage, skipping")
                    continue
                }
                
                try await userKeysStorage.save(userKey: legacyKey)
                migratedCount += 1
                logger?.i("Migrated key for user: \(legacyKey.userId)")
            }
            
            logger?.i("Successfully migrated \(migratedCount) user keys to new storage")
            
            // Step 3: Cleanup legacy data
            if cleanupLegacyData {
                do {
                    try await legacyStorage.deleteLegacyData()
                    logger?.i("Successfully deleted legacy keychain data")
                } catch {
                    logger?.w("Failed to delete legacy keychain data: \(error.localizedDescription)", error: error)
                    // Don't throw here, migration was successful even if cleanup failed
                }
            } else {
                logger?.i("Skipping cleanup of legacy data as requested")
            }
            
            await stateManager.markAttempted()
            logger?.i("Device binding migration completed successfully")
            
        } catch let error as MigrationError {
            logger?.e("Migration failed with MigrationError", error: error)
            await stateManager.markAttempted()
            throw error
        } catch {
            logger?.e("Migration failed with unexpected error", error: error)
            await stateManager.markAttempted()
            throw MigrationError.failedToReadLegacyKeys(error)
        }
    }
    
    /// Resets the migration attempted flag for testing purposes.
    /// - Warning: This should only be used in test environments.
    public static func resetMigrationState() async {
        await stateManager.reset()
    }
}
