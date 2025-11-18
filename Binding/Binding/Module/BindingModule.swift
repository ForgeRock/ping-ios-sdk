
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
import PingJourney
import PingMfaCommons

/// A module for handling device binding and signing callbacks.
/// The callbacks are automatically registered when `CallbackRegistry.shared.registerDefaultCallbacks()` is called.
/// Manual registration using `BindingModule.register()` is optional and only needed if you're not using the Journey framework.
public class BindingModule: NSObject {
    
    /// Initializes a new `BindingModule`.
    public override init() {}
    
    /// Registers the device binding and signing callbacks with the `CallbackRegistry`.
    /// 
    /// **Note:** This method is optional when using the Journey framework, as callbacks are automatically
    /// registered when `CallbackRegistry.shared.registerDefaultCallbacks()` is called.
    /// Only call this method if you need to register callbacks manually outside of the Journey flow.
    @objc public static func registerCallbacks() {
        CallbackRegistry.shared.register(type: Constants.deviceBindingCallback, callback: DeviceBindingCallback.self)
        CallbackRegistry.shared.register(type: Constants.deviceSigningVerifierCallback, callback: DeviceSigningVerifierCallback.self)
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

