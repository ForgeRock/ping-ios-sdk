
//
//  UserKeyStorageConfig.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingStorage


/// Configuration for `UserKeysStorage`.
public class UserKeyStorageConfig {
    
    /// The underlying storage mechanism.
    public var storage: any Storage<[UserKey]>
    
    /// The default account name for keychain storage.
    var deviceBindingV1UserKeys = "com.pingidentity.device.binding.v1.userkeys"
    
    /// Initializes a new `UserKeyStorageConfig` with default keychain storage.
    public init() {
        self.storage = KeychainStorage(account: deviceBindingV1UserKeys, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    /// Initializes a new `UserKeyStorageConfig` with custom storage.
    /// - Parameter storage: The storage to use.
    public init(storage: any Storage<[UserKey]>) {
        self.storage = storage
    }
}
