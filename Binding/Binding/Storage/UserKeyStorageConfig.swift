
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

private let deviceBindingV1UserKeys = "com.pingidentity.device.binding.v1.userkeys"

public class UserKeyStorageConfig {
    
    public var storage: any Storage<[UserKey]>
    
    public init() {
        self.storage = KeychainStorage(account: deviceBindingV1UserKeys, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    public init(storage: any Storage<[UserKey]>) {
        self.storage = storage
    }
}
