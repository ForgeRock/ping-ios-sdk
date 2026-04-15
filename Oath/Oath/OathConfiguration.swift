//
//  OathConfiguration.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingCommons

/// Configuration class specific for OATH MFA functionality.
/// Extends the base configuration with OATH-specific settings.
///
/// Example usage:
/// ```swift
/// let config = OathConfiguration.build { config in
///     config.storage = OathKeychainStorage()
///     config.enableCredentialCache = false
///     config.logger = customLogger
/// }
/// ```
public final class OathConfiguration: @unchecked Sendable {

    // MARK: - Properties
    
    /// The storage implementation to use for OATH credentials.
    /// If nil, a default OathKeychainStorage will be used.
    public var storage: (any OathStorage)?

    /// The policy evaluator to use for credential policy validation.
    /// If nil, default policies will be used.
    public var policyEvaluator: MfaPolicyEvaluator?

    /// Whether data encryption is enabled for storage.
    /// Defaults to true for enhanced security.
    public var encryptionEnabled: Bool = true

    /// The timeout for network operations in seconds.
    /// Defaults to 15.0 seconds.
    public var timeoutMs: TimeInterval = 15.0

    /// Whether to enable in-memory caching of credentials.
    /// By default, this is disabled for security reasons, as an attacker
    /// could potentially access cached credentials from memory dumps.
    public var enableCredentialCache: Bool = false

    /// The logger instance used for logging messages.
    /// If nil, no logging will be performed.
    public var logger: Logger = LogManager.logger

    
    // MARK: - Initializers

    /// Creates a new OATH configuration with default values.
    public init() {}

    
    // MARK: - Factory Methods

    /// Creates a new instance of OathConfiguration with the provided configuration block.
    /// - Parameter configure: A closure that configures the OathConfiguration instance.
    /// - Returns: A configured OathConfiguration instance.
    ///
    /// Example usage:
    /// ```swift
    /// let config = OathConfiguration.build { config in
    ///     config.storage = MyOathStorage()
    ///     config.enableCredentialCache = false
    /// }
    /// ```
    public static func build(_ configure: (OathConfiguration) -> Void) -> OathConfiguration {
        let config = OathConfiguration()
        configure(config)
        return config
    }
}
