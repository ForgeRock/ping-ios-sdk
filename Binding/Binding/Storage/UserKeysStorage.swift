//
//  UserKeysStorage.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingStorage

/// A class for managing the persistence of user keys.
class UserKeysStorage {
    
    private let config: UserKeyStorageConfig
    
    /// Initializes a new `UserKeysStorage`.
    /// - Parameter config: The configuration to use.
    init(config: UserKeyStorageConfig) {
        self.config = config
    }
    
    /// Saves a user key.
    ///
    /// - Parameter userKey: The user key to save.
    func save(userKey: UserKey) async throws {
        var userKeys = try await findAll()
        userKeys.append(userKey)
        try await config.storage.save(item: userKeys)
    }
    
    /// Finds all user keys.
    ///
    /// - Returns: An array of user keys.
    func findAll() async throws -> [UserKey] {
        return (try? await config.storage.get()) ?? []
    }
    
    /// Finds a user key by user ID.
    ///
    /// - Parameter userId: The user ID.
    /// - Returns: The user key, or nil if not found.
    func findByUserId(_ userId: String) async throws -> UserKey? {
        let userKeys = try await findAll()
        return userKeys.first { $0.userId == userId }
    }
    
    /// Deletes a user key by user ID.
    /// - Parameter userId: The user ID of the key to delete.
    func deleteByUserId(_ userId: String) async throws {
        var userKeys = try await findAll()
        userKeys.removeAll { $0.userId == userId }
        try await config.storage.save(item: userKeys)
    }
    
    /// Deletes all user keys.
    func deleteAll() async throws {
        try await config.storage.delete()
    }
}
