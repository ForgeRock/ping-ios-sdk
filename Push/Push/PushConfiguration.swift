//
//  PushConfiguration.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingMfaCommons

/// Configuration class specific for Push MFA functionality.
///
/// This configuration allows customization of storage, network behavior, caching,
/// cleanup policies, and platform handlers. It follows a builder pattern for easy setup.
///
/// ## Usage Examples
///
/// ```swift
/// // Simple configuration with defaults
/// let config1 = PushConfiguration.build { config in
///     config.logger = myLogger
/// }
///
/// // Custom configuration
/// let config2 = PushConfiguration.build { config in
///     config.storage = MyCustomStorage()
///     config.timeoutMs = 20000
///     config.enableCredentialCache = true
///     config.notificationCleanupConfig = .hybrid(maxNotifications: 50, maxAgeDays: 14)
/// }
///
/// // Security-focused configuration
/// let config3 = PushConfiguration.build { config in
///     config.encryptionEnabled = true
///     config.enableCredentialCache = false  // No in-memory caching
///     config.notificationCleanupConfig = .ageBased(maxAgeDays: 7)
/// }
/// ```
///
/// ## Default Values
///
/// - **storage**: `nil` (PushKeychainStorage will be used)
/// - **policyEvaluator**: `nil` (default policies will be used)
/// - **encryptionEnabled**: `true`
/// - **timeoutMs**: `15000` (15 seconds)
/// - **enableCredentialCache**: `false` (disabled for security)
/// - **logger**: `nil` (no logging)
/// - **customPushHandlers**: `[:]` (empty dictionary)
/// - **notificationCleanupConfig**: count-based with 100 max notifications
public final class PushConfiguration: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The storage implementation to use for Push credentials and notifications.
    ///
    /// If `nil`, a default `PushKeychainStorage` will be created and used.
    /// Custom storage implementations must conform to the `PushStorage` protocol.
    ///
    /// ## Example
    ///
    /// ```swift
    /// config.storage = MyCustomPushStorage()
    /// ```
    public var storage: (any PushStorage)?
    
    /// The policy evaluator to use for credential policy validation.
    ///
    /// If `nil`, default policies from `PingMfaCommons` will be used.
    ///
    /// If `nil`, default policies from `PingMfaCommons` will be used.
    /// Policy evaluators check for device security issues like jailbreak detection,
    /// debugger attachment, and other security concerns.
    ///
    /// ## Example
    ///
    /// ```swift
    /// config.policyEvaluator = MyCustomPolicyEvaluator()
    /// ```
    public var policyEvaluator: MfaPolicyEvaluator?
    
    /// Whether data encryption is enabled for storage.
    ///
    /// When enabled, sensitive data (credentials, shared secrets) will be encrypted
    /// before being stored in the Keychain. This provides an additional layer of security.
    ///
    /// Default value is `true` for enhanced security.
    public var encryptionEnabled: Bool = true
    
    /// The timeout for network operations in milliseconds.
    ///
    /// This timeout applies to all network requests made by the Push client,
    /// including registration, authentication, and device token updates.
    ///
    /// Default value is `15000` milliseconds (15 seconds).
    ///
    /// ## Example
    ///
    /// ```swift
    /// config.timeoutMs = 30000  // 30 seconds
    /// ```
    public var timeoutMs: Int = 15000
    
    /// Whether to enable in-memory caching of credentials.
    ///
    /// By default, this is **disabled** for security reasons. When enabled, credentials
    /// are cached in memory to reduce Keychain access overhead. However, this means
    /// credentials could potentially be accessed from memory dumps by an attacker.
    ///
    /// Default value is `false`.
    ///
    /// ## Security Note
    ///
    /// Only enable this if you understand the security implications and your
    /// threat model allows for in-memory credential storage.
    public var enableCredentialCache: Bool = false
    
    /// The logger instance used for logging messages.
    ///
    /// If `nil`, no logging will be performed. When set, the Push client will
    /// log important events, errors, and debug information using this logger.
    ///
    /// ## Example
    ///
    /// ```swift
    /// config.logger = PingLogger(logLevel: .debug)
    /// ```
    public var logger: Logger?
    
    /// Map of custom PushHandlers that will be used along with default handlers.
    ///
    /// The key is the platform identifier (e.g., "PING_AM", "CUSTOM_PLATFORM"),
    /// and the value is the handler implementation conforming to `PushHandler` protocol.
    ///
    /// Custom handlers allow you to extend the Push client to support additional
    /// push notification platforms beyond the built-in PingAM support.
    ///
    /// Default value is an empty dictionary.
    ///
    /// ## Example
    ///
    /// ```swift
    /// config.customPushHandlers = [
    ///     "MY_PLATFORM": MyCustomPushHandler()
    /// ]
    /// ```
    public var customPushHandlers: [String: Any] = [:]
    
    /// Configuration for automatic cleanup of push notifications.
    ///
    /// This determines how old or excessive notifications are automatically removed
    /// to manage storage. The cleanup can happen automatically when processing new
    /// notifications, or manually by calling cleanup methods.
    ///
    /// Default value uses count-based cleanup with a maximum of 100 notifications.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Keep only 50 notifications
    /// config.notificationCleanupConfig = .countBased(maxNotifications: 50)
    ///
    /// // Remove notifications older than 7 days
    /// config.notificationCleanupConfig = .ageBased(maxAgeDays: 7)
    ///
    /// // Hybrid approach
    /// config.notificationCleanupConfig = .hybrid(
    ///     maxNotifications: 50,
    ///     maxAgeDays: 14
    /// )
    /// ```
    public var notificationCleanupConfig: NotificationCleanupConfig = .default()
    
    // MARK: - Initialization
    
    /// Creates a new Push configuration with default values.
    ///
    /// Use the `build` factory method instead for a more fluent configuration experience.
    public init() {}
    
    // MARK: - Factory Methods
    
    /// Creates a new instance of PushConfiguration with the provided configuration block.
    ///
    /// This factory method provides a clean, DSL-style way to configure the Push client.
    /// The configuration block receives a `PushConfiguration` instance that can be
    /// customized before being returned.
    ///
    /// - Parameter configure: A closure that configures the PushConfiguration instance.
    /// - Returns: A configured PushConfiguration instance.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = PushConfiguration.build { config in
    ///     config.storage = MyPushStorage()
    ///     config.enableCredentialCache = false
    ///     config.timeoutMs = 20000
    ///     config.logger = PingLogger(logLevel: .info)
    ///     config.notificationCleanupConfig = .hybrid(
    ///         maxNotifications: 50,
    ///         maxAgeDays: 14
    ///     )
    /// }
    ///
    /// let client = try await PushClient.createClient(configuration: config)
    /// ```
    public static func build(_ configure: (PushConfiguration) -> Void) -> PushConfiguration {
        let config = PushConfiguration()
        configure(config)
        return config
    }
}
