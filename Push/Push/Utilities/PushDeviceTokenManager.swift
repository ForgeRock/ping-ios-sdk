//
//  PushDeviceTokenManager.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Manages storage and retrieval of the Push device token.
///
/// The device token is issued by APNs and must be registered with PingAM so the
/// server can deliver push challenges to the device. This manager wraps `PushStorage`
/// to provide a focused API for storing, retrieving, and comparing device tokens.
///
/// Usage:
/// ```swift
/// let manager = PushDeviceTokenManager(storage: storage, logger: logger)
/// try await manager.storeDeviceToken(tokenString)
/// let hasChanged = try await manager.hasTokenChanged(tokenString)
/// ```
actor PushDeviceTokenManager {

    /// Storage implementation responsible for persisting device tokens.
    private let storage: any PushStorage

    /// Optional logger for diagnostic output.
    private let logger: Logger?

    /// Creates a new device token manager.
    /// - Parameters:
    ///   - storage: The storage implementation used to persist device tokens.
    ///   - logger: Optional logger used for diagnostic messages.
    init(storage: any PushStorage, logger: Logger? = nil) {
        self.storage = storage
        self.logger = logger
    }

    /// Stores the latest APNs device token.
    ///
    /// - Parameter token: Raw device token string received from APNs.
    /// - Throws: `PushError.invalidParameterValue` when the token is empty.
    /// - Throws: `PushError.storageFailure` when the token cannot be persisted.
    func storeDeviceToken(_ token: String) async throws {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedToken.isEmpty else {
            logger?.w("Attempted to store an empty device token", error: nil)
            throw PushError.invalidParameterValue("Device token cannot be empty")
        }

        logger?.i("Storing device token")

        do {
            let pushToken = PushDeviceToken(token: normalizedToken)
            try await storage.storePushDeviceToken(pushToken)
            logger?.i("Stored device token with identifier \(pushToken.id)")
        } catch {
            logger?.e("Failed to store device token", error: error)
            throw PushError.storageFailure("Failed to store device token", error)
        }
    }

    /// Retrieves the currently stored device token string.
    ///
    /// - Returns: The stored device token string, or `nil` when no token is persisted.
    /// - Throws: `PushError.storageFailure` when the token cannot be retrieved.
    func getDeviceTokenId() async throws -> String? {
        do {
            let storedToken = try await storage.getCurrentPushDeviceToken()

            if let storedToken {
                logger?.d("Retrieved stored device token")
                return storedToken.token
            }

            logger?.d("No stored device token found")
            return nil
        } catch {
            logger?.e("Failed to retrieve stored device token", error: error)
            throw PushError.storageFailure("Failed to retrieve device token", error)
        }
    }

    /// Determines whether the supplied token differs from the stored token.
    ///
    /// - Parameter newToken: The device token string received from APNs.
    /// - Returns: `true` when the token differs or no token is stored, `false` otherwise.
    /// - Throws: `PushError.invalidParameterValue` when the provided token is empty.
    /// - Throws: `PushError.storageFailure` when comparison cannot be performed.
    func hasTokenChanged(_ newToken: String) async throws -> Bool {
        let normalizedToken = newToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedToken.isEmpty else {
            logger?.w("Received empty device token for change detection", error: nil)
            throw PushError.invalidParameterValue("Device token cannot be empty")
        }

        do {
            guard let currentToken = try await getDeviceTokenId() else {
                logger?.d("No stored token present; treating as changed")
                return true
            }

            let changed = currentToken != normalizedToken
            logger?.d("Device token change detected: \(changed)")
            return changed
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to compare device tokens", error: error)
            throw PushError.storageFailure("Failed to compare device tokens", error)
        }
    }
}
