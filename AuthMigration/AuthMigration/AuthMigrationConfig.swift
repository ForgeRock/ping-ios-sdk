//
//  AuthMigrationConfig.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingOath
import PingPush

/// Configuration for the authenticator migration process.
///
/// `AuthMigrationConfig` allows callers to customize migration behavior through a DSL-style
/// closure passed to ``AuthMigration/start(configure:)`` or ``AuthMigration/migrateIfNeeded(configure:)``.
///
/// All properties have sensible defaults, so no configuration is required for standard
/// `FRAuthenticator` installations that use the default `KeychainServiceClient`.
///
/// ## Default Configuration
///
/// ```swift
/// // Uses all defaults — equivalent to passing no closure
/// let stream = AuthMigration.start()
/// ```
///
/// ## Custom Configuration
///
/// ```swift
/// let stream = AuthMigration.start { config in
///     config.accessGroup = "com.myapp.shared"
///     config.logger = LogManager.logger
///     config.cleanupLegacyData = false
///     config.oathStorage = OathKeychainStorage(options: customOptions)
///     config.pushStorage = PushKeychainStorage(options: customOptions)
/// }
/// ```
///
/// - SeeAlso: ``AuthMigration``
/// - SeeAlso: ``AuthMigrationError``
public final class AuthMigrationConfig: @unchecked Sendable {

    /// The Keychain access group used by the legacy `FRAuthenticator` SDK.
    ///
    /// Set this if the legacy SDK was configured with a shared Keychain access group
    /// (e.g., for app extension support). If `nil`, the default Keychain access group
    /// is used, which matches the default `FRAuthenticator` configuration.
    ///
    /// - Note: This must match the access group that was configured in the legacy SDK.
    ///   If the access groups don't match, migration will report ``AuthMigrationError/noLegacyDataFound``.
    public var accessGroup: String? = nil

    /// Logger for migration progress and diagnostics.
    ///
    /// All pipeline events (step transitions, credential counts, errors) are logged through
    /// this logger. Set to `nil` to suppress migration logging entirely.
    ///
    /// Defaults to `nil` (no logging).
    public var logger: Logger? = nil

    /// Whether to delete legacy Keychain data after successful migration.
    ///
    /// When `true` (the default), legacy Keychain entries from all four `FRAuthenticator`
    /// services (account, mechanism, notification, device token) are deleted after credentials
    /// are successfully migrated to the new storage.
    ///
    /// Set to `false` to preserve legacy data for debugging or in case a rollback is needed.
    /// Cleanup failures are logged as warnings but do not cause the migration to fail.
    ///
    /// Defaults to `true`.
    public var cleanupLegacyData: Bool = true

    /// Custom OATH credential storage.
    ///
    /// If `nil`, uses the default ``OathKeychainStorage`` with standard security options.
    /// Provide a custom implementation if the app uses non-default Keychain configuration
    /// (e.g., custom access group, biometric protection).
    ///
    /// - SeeAlso: `OathStorage`
    /// - SeeAlso: `OathKeychainStorage`
    public var oathStorage: (any OathStorage)? = nil

    /// Custom Push credential storage.
    ///
    /// If `nil`, uses the default ``PushKeychainStorage`` with standard security options.
    /// Provide a custom implementation if the app uses non-default Keychain configuration.
    ///
    /// - SeeAlso: `PushStorage`
    /// - SeeAlso: `PushKeychainStorage`
    public var pushStorage: (any PushStorage)? = nil

    /// Creates a new configuration with default values.
    public init() {}
}
