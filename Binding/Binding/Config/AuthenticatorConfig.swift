//
//  AuthenticatorConfig.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingLogger
import Foundation

public protocol AuthenticatorConfig {
    /// Logger instance used for debugging and monitoring authentication operations.
    var logger: Logger? {get set}
    
    /// The key tag to use for the CryptoKey.
    var keyTag: String {get set}
}
