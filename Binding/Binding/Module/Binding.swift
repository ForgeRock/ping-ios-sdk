
//
//  Binding.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
import PingMfaCommons

/// A module for handling device binding and signing callbacks.
/// This module registers the `DeviceBindingCallback` and `DeviceSigningVerifierCallback` with the `CallbackRegistry`.
public class BindingModule {
    
    /// Initializes a new `BindingModule`.
    public init() {}
    
    /// Registers the device binding and signing callbacks with the `CallbackRegistry`.
    /// This method should be called once at application startup.
    public static func register() {
        CallbackRegistry.shared.register(type: "DeviceBindingCallback", callback: DeviceBindingCallback.self)
        CallbackRegistry.shared.register(type: "DeviceSigningVerifierCallback", callback: DeviceSigningVerifierCallback.self)
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

