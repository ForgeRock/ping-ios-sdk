//
//  BiometricAuthenticatorConfig.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Configuration class for biometric authenticators.
public class BiometricAuthenticatorConfig: AuthenticatorConfig {
    
    /// Logger instance used for debugging and monitoring authentication operations.
    public var logger: Logger?
    
    /// The key tag to use for the CryptoKey.
    public var keyTag: String
    
    /// Initializes a new `BiometricAuthenticatorConfig`.
    public init(logger: Logger? = nil,
                keyTag: String = UUID().uuidString) {
        self.logger = logger
        self.keyTag = keyTag
    }
}
