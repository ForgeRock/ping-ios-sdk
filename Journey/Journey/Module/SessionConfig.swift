//
//  SessionConfig.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate
import PingStorage

class SessionConfig: @unchecked Sendable {
    /// Optional storage that can be lazily initialized
    var storage: any Storage<SSOTokenImpl>

    /// Initialize storage if it's not already set
    public init() {
        storage = KeychainStorage<SSOTokenImpl>(account: SharedContext.Keys.sessionConfigKey, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
}


extension SharedContext.Keys {
    /// The key used to store the sessionConfigKey
    public static let sessionConfigKey = "com.pingidentity.journey.SessionConfig"
}
