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

/// A configuration class for managing session-related settings.
public class SessionConfig: @unchecked Sendable {
    /// Storage for SSO tokens. Can be customized per Journey instance.
    /// Defaults to KeychainStorage with a default account identifier.
    public var storage: any Storage<SSOTokenImpl>

    /// Initialize storage with default KeychainStorage
    public init() {
        storage = KeychainStorage<SSOTokenImpl>(account: SharedContext.Keys.sessionConfigKey, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    /// Initialize storage with a custom account identifier
    /// - Parameter account: A unique identifier for this session storage
    public convenience init(account: String) {
        self.init()
        storage = KeychainStorage<SSOTokenImpl>(account: account, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
}


extension SharedContext.Keys {
    /// The key used to store the sessionConfigKey
    public static let sessionConfigKey = "com.pingidentity.journey.SessionConfig"
}
