//
//  NotificationCleanupManager.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Coordinates automatic cleanup of stored push notifications.
///
/// This manager executes the strategies configured in `NotificationCleanupConfig`
/// against an underlying `PushStorage` implementation. It is used by the Push client to
/// ensure notifications do not accumulate indefinitely and consume unnecessary storage.
actor NotificationCleanupManager {

    /// Storage layer providing access to persisted notifications.
    private let storage: any PushStorage

    /// Cleanup strategy configuration.
    private let config: NotificationCleanupConfig

    /// Optional logger for diagnostic events.
    private let logger: Logger?

    /// Creates a new cleanup manager.
    /// - Parameters:
    ///   - storage: Storage implementation used to manage notifications.
    ///   - config: Cleanup configuration describing which strategy to use.
    ///   - logger: Optional logger instance for diagnostics.
    init(
        storage: any PushStorage,
        config: NotificationCleanupConfig,
        logger: Logger? = nil
    ) {
        self.storage = storage
        self.config = config
        self.logger = logger
    }

    /// Executes the configured cleanup strategy.
    ///
    /// - Parameter credentialId: Optional credential identifier used to scope the cleanup.
    /// - Returns: Number of notifications removed by the cleanup process.
    /// - Throws: `PushError.storageFailure` when storage operations fail.
    func runCleanup(credentialId: String? = nil) async throws -> Int {
        logger?.i("Running notification cleanup using mode \(config.cleanupMode.rawValue)")

        do {
            switch config.cleanupMode {
            case .none:
                logger?.d("Cleanup mode is NONE; skipping cleanup")
                return 0

            case .countBased:
                return try await cleanupByCount(credentialId: credentialId)

            case .ageBased:
                return try await cleanupByAge(credentialId: credentialId)

            case .hybrid:
                let countRemoved = try await cleanupByCount(credentialId: credentialId)
                let ageRemoved = try await cleanupByAge(credentialId: credentialId)
                return countRemoved + ageRemoved
            }
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Cleanup operation failed", error: error)
            throw PushError.storageFailure("Failed to run notification cleanup", error)
        }
    }

    /// Removes notifications that exceed the configured count limit.
    ///
    /// - Parameter credentialId: Optional credential identifier to limit the scope.
    /// - Returns: Number of notifications removed.
    /// - Throws: `PushError.storageFailure` when storage operations fail.
    private func cleanupByCount(credentialId: String?) async throws -> Int {
        logger?.d("Executing count-based notification cleanup")

        do {
            let removed = try await storage.purgePushNotificationsByCount(
                maxCount: config.maxStoredNotifications,
                credentialId: credentialId
            )
            logger?.d("Count-based cleanup removed \(removed) notifications")
            return removed
        } catch {
            logger?.e("Count-based cleanup failed", error: error)
            throw PushError.storageFailure("Failed to purge notifications by count", error)
        }
    }

    /// Removes notifications older than the configured age threshold.
    ///
    /// - Parameter credentialId: Optional credential identifier to limit the scope.
    /// - Returns: Number of notifications removed.
    /// - Throws: `PushError.storageFailure` when storage operations fail.
    private func cleanupByAge(credentialId: String?) async throws -> Int {
        logger?.d("Executing age-based notification cleanup")

        do {
            let removed = try await storage.purgePushNotificationsByAge(
                maxAgeDays: config.maxNotificationAgeDays,
                credentialId: credentialId
            )
            logger?.d("Age-based cleanup removed \(removed) notifications")
            return removed
        } catch {
            logger?.e("Age-based cleanup failed", error: error)
            throw PushError.storageFailure("Failed to purge notifications by age", error)
        }
    }
}
