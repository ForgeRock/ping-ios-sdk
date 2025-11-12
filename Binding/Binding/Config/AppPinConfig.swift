//
//  AppPinConfig.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Configuration class for `AppPinAuthenticator` that defines PIN collection, storage, and security settings.
public class AppPinConfig: AuthenticatorConfig {
    
    /// Logger instance used for debugging and monitoring authentication operations.
    public var logger: Logger?
    
    /// The prompt object containing title and description to be shown to the user.
    public var prompt: Prompt
    
    /// The number of PIN retry attempts before lockout.
    public var pinRetry: Int
    
    /// The key tag to use for the CryptoKey.
    public var keyTag: String
    
    #if canImport(UIKit)
    /// The pin collector to be used.
    public var pinCollector: PinCollector
    #endif
    
    /// Initializes a new `AppPinConfig`.
    public init(logger: Logger? = nil,
                prompt: Prompt = Prompt(title: "Enter PIN", subtitle: "", description: "Please enter your application PIN to continue."),
                pinRetry: Int = 3,
                keyTag: String = UUID().uuidString,
                pinCollector: PinCollector? = nil) {
        self.logger = logger
        self.prompt = prompt
        self.pinRetry = pinRetry
        self.keyTag = keyTag
        #if canImport(UIKit)
        self.pinCollector = pinCollector ?? DefaultPinCollector()
        #endif
    }
}
