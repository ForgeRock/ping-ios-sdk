//
//  BindingModule.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin
import PingCommons
import PingLogger

/// Actor to manage migration state in a thread-safe manner
private actor MigrationState {
    private var migrationTask: Task<Void, Never>?
    var logger: Logger?
    
    func getMigrationTask(createIfNeeded: Bool = true) -> Task<Void, Never>? {
        if migrationTask == nil && createIfNeeded {
            migrationTask = Task {
                do {
                    try await BindingMigration.migrate(logger: logger)
                } catch MigrationError.noLegacyDataFound {
                    // This is expected for new installations or already migrated apps
                    logger?.i("No legacy data to migrate")
                } catch {
                    // Log but don't fail - the app should continue working
                    logger?.w("Migration failed: \(error.localizedDescription)", error: error)
                }
            }
        }
        return migrationTask
    }
    
    func setLogger(_ logger: Logger) {
        self.logger = logger
    }
}

/// A module for handling device binding and signing callbacks.
/// The callbacks are automatically registered when `CallbackRegistry.shared.registerDefaultCallbacks()` is called.
/// Manual registration using `BindingModule.register()` is optional and only needed if you're not using the Journey framework.
public class BindingModule: NSObject {
    
    /// Shared migration state
    private static let migrationState = MigrationState()
    
    /// Initializes a new `BindingModule`.
    public override init() {}
    
    /// Registers the device binding and signing callbacks with the `CallbackRegistry`.
    /// 
    /// **Note:** This method is optional when using the Journey framework, as callbacks are automatically
    /// registered when `CallbackRegistry.shared.registerDefaultCallbacks()` is called.
    /// Only call this method if you need to register callbacks manually outside of the Journey flow.
    @objc public static func registerCallbacks() {
        Task {
            /// Register Callbacks
            await CallbackRegistry.shared.register(type: Constants.deviceBindingCallback, callback: DeviceBindingCallback.self)
            await CallbackRegistry.shared.register(type: Constants.deviceSigningVerifierCallback, callback: DeviceSigningVerifierCallback.self)
        
            // Trigger migration check on callback registration
            await triggerMigrationIfNeeded()
        }
    }
    
    /// Triggers the migration check if it hasn't been done yet.
    /// This is called automatically during module initialization.
    private static func triggerMigrationIfNeeded() async {
        // Get or create the migration task - only one task will ever be created
        guard let migrationTask = await migrationState.getMigrationTask() else {
            return
        }
        
        // Wait for the migration to complete
        await migrationTask.value
    }
    
    /// Sets the logger for the BindingModule and migration.
    /// - Parameter logger: The logger to use.
    public static func setLogger(_ logger: Logger) {
        Task {
            await migrationState.setLogger(logger)
        }
    }
    
    /// Retrieves all stored binding keys.
    /// - Returns: An array of `UserKey` objects.
    /// - Throws: An error if the keys cannot be fetched.
    public static func getAllKeys() async throws -> [UserKey] {
        return try await UserKeysStorage(config: UserKeyStorageConfig()).findAll()
    }
    
    /// Deletes a specific binding key.
    /// - Parameter key: The `UserKey` to delete.
    /// - Throws: An error if the key cannot be deleted.
    public static func deleteKey(_ key: UserKey) async throws {
        try CryptoKey(keyTag: key.keyTag).deleteKeyPair()
        try await UserKeysStorage(config: UserKeyStorageConfig()).deleteByUserId(key.userId)
    }
    
    /// Deletes all stored binding keys.
    /// - Throws: An error if deletion fails.
    public static func deleteAllKeys() async throws {
        let storage = UserKeysStorage(config: UserKeyStorageConfig())
        let allKeys = try await storage.findAll()
        for key in allKeys {
            try CryptoKey(keyTag: key.keyTag).deleteKeyPair()
            try await storage.deleteByUserId(key.userId)
        }
    }
}

