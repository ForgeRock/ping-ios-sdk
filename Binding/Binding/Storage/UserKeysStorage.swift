/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

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
    func save(userKey: UserKey) throws {
        var userKeys = try findAll()
        userKeys.append(userKey)
        let data = try JSONEncoder().encode(userKeys)
        try data.write(to: fileURL)
    }
    
    /// Finds all user keys.
    ///
    /// - Returns: An array of user keys.
    func findAll() throws -> [UserKey] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return try JSONDecoder().decode([UserKey].self, from: data)
    }
    
    /// Finds a user key by user ID.
    ///
    /// - Parameter userId: The user ID.
    /// - Returns: The user key, or nil if not found.
    func findByUserId(_ userId: String) throws -> UserKey? {
        let userKeys = try findAll()
        return userKeys.first { $0.userId == userId }
    }
    
    /// Deletes a user key by user ID.
    /// - Parameter userId: The user ID of the key to delete.
    func deleteByUserId(_ userId: String) throws {
        var userKeys = try findAll()
        userKeys.removeAll { $0.userId == userId }
        let data = try JSONEncoder().encode(userKeys)
        try data.write(to: fileURL)
    }
    
    /// The URL of the file where the keys are stored.
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(config.fileName)
    }
}
