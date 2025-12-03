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

/// A configuration class for managing session-related settings and SSO token storage.
///
/// `SessionConfig` provides a centralized way to configure how SSO tokens are stored
/// and persisted across app launches. By default, it uses secure Keychain storage
/// with encryption, but can be customized to use different storage backends or
/// account identifiers for multi-user scenarios.
///
/// ## Default Behavior
///
/// When initialized without parameters, `SessionConfig` uses:
/// - **Storage**: Keychain-based storage
/// - **Account**: Default identifier (`com.pingidentity.journey.SessionConfig`)
/// - **Encryption**: Secured key encryption when available, falling back to no encryption
///
/// ## Custom Storage Configuration
///
/// For apps supporting multiple users or requiring isolated storage:
///
/// ```swift
/// let journey = Journey.createJourney { config in
///     // ... other configuration ...
///
///     // After initialization, customize session storage
/// }
///
/// // Configure custom session storage after journey initialization
/// try await journey.initialize()
/// if let sessionConfig = journey.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig {
///     sessionConfig.storage = KeychainStorage<SSOTokenImpl>(
///         account: "user_specific_account",
///         encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
///     )
/// }
/// ```
///
/// ## Multi-User Scenarios
///
/// When your app needs to support multiple concurrent users with isolated sessions,
/// create separate Journey instances with unique account identifiers:
///
/// ```swift
/// // User A's journey with isolated storage
/// let userAJourney = Journey.createJourney { config in
///     // configuration...
/// }
/// try await userAJourney.initialize()
/// if let sessionConfig = userAJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig {
///     sessionConfig.storage = KeychainStorage<SSOTokenImpl>(account: "user_a_sessions", encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
/// }
///
/// // User B's journey with separate isolated storage
/// let userBJourney = Journey.createJourney { config in
///     // configuration...
/// }
/// try await userBJourney.initialize()
/// if let sessionConfig = userBJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig {
///     sessionConfig.storage = KeychainStorage<SSOTokenImpl>(account: "user_b_sessions", encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
/// }
/// ```
///
/// - Important: Session storage should be configured after calling `journey.initialize()`
///   to ensure the SessionModule has properly set up the initial configuration.
///
/// - Note: This class is marked as `@unchecked Sendable` because its storage property
///   is mutable but protected by actor isolation in practice through the Journey architecture.
public class SessionConfig: @unchecked Sendable {
    /// Storage for SSO tokens. Can be customized per Journey instance.
    ///
    /// The storage backend manages persistence of ``SSOTokenImpl`` objects, which contain
    /// session values, success URLs, and realm information. By default, this uses
    /// `KeychainStorage` with secure encryption.
    ///
    /// You can replace this with:
    /// - A custom `Storage` implementation
    /// - `KeychainStorage` with a different account identifier
    /// - A mock storage for testing purposes
    ///
    /// ## Example: Custom Storage
    ///
    /// ```swift
    /// sessionConfig.storage = KeychainStorage<SSOTokenImpl>(
    ///     account: "custom_account_id",
    ///     encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
    /// )
    /// ```
    public var storage: any Storage<SSOTokenImpl>

    /// Initializes a new `SessionConfig` with default Keychain storage.
    ///
    /// This initializer creates a session configuration using:
    /// - Keychain storage for secure persistence
    /// - Default account identifier (`com.pingidentity.journey.SessionConfig`)
    /// - Secured key encryption when available
    ///
    /// The default configuration is suitable for most single-user scenarios where
    /// session isolation is not required.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sessionConfig = SessionConfig()
    /// // Uses default keychain storage with standard account identifier
    /// ```
    ///
    /// - SeeAlso: `init(account:)` for custom account identifiers
    public init() {
        storage = KeychainStorage<SSOTokenImpl>(account: SharedContext.Keys.sessionConfigKey, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    /// Initializes a new `SessionConfig` with a custom account identifier for Keychain storage.
    ///
    /// Use this initializer when you need to isolate session storage with a unique
    /// identifier. This is particularly useful for:
    /// - Multi-user applications where each user needs separate session storage
    /// - Testing scenarios requiring isolated storage
    /// - Apps with multiple authentication contexts
    ///
    /// The account identifier serves as the Keychain account attribute, allowing
    /// multiple session stores to coexist without conflicts.
    ///
    /// ## Example: Multi-User Storage
    ///
    /// ```swift
    /// // Create session config for a specific user
    /// let userSessionConfig = SessionConfig(account: "user_12345_sessions")
    ///
    /// // Each user gets isolated storage
    /// let adminSessionConfig = SessionConfig(account: "admin_sessions")
    /// ```
    ///
    /// - Parameter account: A unique identifier for this session storage instance.
    ///   This value is used as the Keychain account attribute. Choose a descriptive
    ///   and unique value to avoid conflicts with other storage instances.
    ///
    /// - Important: Ensure account identifiers are unique across your app to prevent
    ///   unintended session data sharing between different users or contexts.
    ///
    /// - SeeAlso: `init()` for the default configuration
    public convenience init(account: String) {
        self.init()
        storage = KeychainStorage<SSOTokenImpl>(account: account, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
}


extension SharedContext.Keys {
    /// The key used to store the sessionConfigKey
    public static let sessionConfigKey = "com.pingidentity.journey.SessionConfig"
}
