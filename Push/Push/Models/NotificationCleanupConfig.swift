//
//  NotificationCleanupConfig.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Configuration for automatic cleanup of push notifications.
///
/// This configuration allows for managing storage by removing old or excessive notifications.
/// Cleanup can be performed automatically when new notifications are processed, or manually
/// by calling the cleanup methods on the PushClient.
///
/// ## Cleanup Strategies
///
/// - **None**: No automatic cleanup is performed
/// - **Count-Based**: Removes oldest notifications when count exceeds maximum
/// - **Age-Based**: Removes notifications older than specified age
/// - **Hybrid**: Applies both count-based and age-based cleanup
///
/// ## Usage Examples
///
/// ```swift
/// // Count-based cleanup (default)
/// let config1 = NotificationCleanupConfig()
///
/// // Age-based cleanup (remove after 7 days)
/// let config2 = NotificationCleanupConfig(
///     cleanupMode: .ageBased,
///     maxNotificationAgeDays: 7
/// )
///
/// // Hybrid cleanup
/// let config3 = NotificationCleanupConfig(
///     cleanupMode: .hybrid,
///     maxStoredNotifications: 50,
///     maxNotificationAgeDays: 14
/// )
///
/// // No cleanup
/// let config4 = NotificationCleanupConfig(cleanupMode: .none)
/// ```
public struct NotificationCleanupConfig: Sendable {
    
    /// Cleanup mode determines how notifications are cleaned up.
    public enum CleanupMode: String, CaseIterable, Sendable {
        /// No automatic cleanup.
        ///
        /// Notifications will accumulate indefinitely until manually removed.
        /// Use this mode if you want full control over notification lifecycle.
        case none = "NONE"
        
        /// Cleanup based on notification count.
        ///
        /// Removes oldest notifications when count exceeds `maxStoredNotifications`.
        /// This ensures storage doesn't grow unbounded while keeping recent notifications.
        case countBased = "COUNT_BASED"
        
        /// Cleanup based on notification age.
        ///
        /// Removes notifications older than `maxNotificationAgeDays`.
        /// This ensures outdated notifications are automatically removed.
        case ageBased = "AGE_BASED"
        
        /// Hybrid cleanup using both count and age.
        ///
        /// Applies both count-based and age-based cleanup strategies.
        /// Notifications are removed if they exceed either the count limit or age limit.
        case hybrid = "HYBRID"
    }
    
    // MARK: - Properties
    
    /// The cleanup mode to use.
    public let cleanupMode: CleanupMode
    
    /// Maximum number of notifications to store per credential (for count-based cleanup).
    ///
    /// When the number of notifications exceeds this value, the oldest notifications
    /// will be removed to bring the count back down to this limit.
    ///
    /// Default value is 100 notifications.
    public let maxStoredNotifications: Int
    
    /// Maximum age of notifications in days (for age-based cleanup).
    ///
    /// Notifications older than this will be removed during cleanup.
    /// The age is calculated from the notification's `createdAt` timestamp.
    ///
    /// Default value is 30 days.
    public let maxNotificationAgeDays: Int
    
    // MARK: - Initialization
    
    /// Creates a new notification cleanup configuration.
    ///
    /// - Parameters:
    ///   - cleanupMode: The cleanup mode to use. Defaults to `.countBased`.
    ///   - maxStoredNotifications: Maximum notifications to store. Defaults to 100.
    ///   - maxNotificationAgeDays: Maximum age in days. Defaults to 30.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig(
    ///     cleanupMode: .hybrid,
    ///     maxStoredNotifications: 50,
    ///     maxNotificationAgeDays: 14
    /// )
    /// ```
    public init(
        cleanupMode: CleanupMode = .countBased,
        maxStoredNotifications: Int = 100,
        maxNotificationAgeDays: Int = 30
    ) {
        self.cleanupMode = cleanupMode
        self.maxStoredNotifications = max(1, maxStoredNotifications)
        self.maxNotificationAgeDays = max(1, maxNotificationAgeDays)
    }
    
    // MARK: - Factory Methods
    
    /// Creates a default notification cleanup configuration.
    ///
    /// The default configuration uses count-based cleanup with a maximum
    /// of 100 notifications and a 30-day age limit.
    ///
    /// - Returns: A configuration with default settings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig.default()
    /// // Equivalent to: NotificationCleanupConfig()
    /// ```
    public static func `default`() -> NotificationCleanupConfig {
        NotificationCleanupConfig()
    }
    
    /// Creates a configuration with no automatic cleanup.
    ///
    /// - Returns: A configuration with cleanup mode set to `.none`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig.none()
    /// ```
    public static func none() -> NotificationCleanupConfig {
        NotificationCleanupConfig(cleanupMode: .none)
    }
    
    /// Creates a configuration for count-based cleanup.
    ///
    /// - Parameter maxNotifications: Maximum number of notifications to keep. Defaults to 100.
    /// - Returns: A configuration with count-based cleanup.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig.countBased(maxNotifications: 50)
    /// ```
    public static func countBased(maxNotifications: Int = 100) -> NotificationCleanupConfig {
        NotificationCleanupConfig(
            cleanupMode: .countBased,
            maxStoredNotifications: maxNotifications
        )
    }
    
    /// Creates a configuration for age-based cleanup.
    ///
    /// - Parameter maxAgeDays: Maximum age in days. Defaults to 30.
    /// - Returns: A configuration with age-based cleanup.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig.ageBased(maxAgeDays: 7)
    /// ```
    public static func ageBased(maxAgeDays: Int = 30) -> NotificationCleanupConfig {
        NotificationCleanupConfig(
            cleanupMode: .ageBased,
            maxNotificationAgeDays: maxAgeDays
        )
    }
    
    /// Creates a configuration for hybrid cleanup.
    ///
    /// - Parameters:
    ///   - maxNotifications: Maximum number of notifications to keep. Defaults to 100.
    ///   - maxAgeDays: Maximum age in days. Defaults to 30.
    /// - Returns: A configuration with hybrid cleanup.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = NotificationCleanupConfig.hybrid(
    ///     maxNotifications: 50,
    ///     maxAgeDays: 14
    /// )
    /// ```
    public static func hybrid(
        maxNotifications: Int = 100,
        maxAgeDays: Int = 30
    ) -> NotificationCleanupConfig {
        NotificationCleanupConfig(
            cleanupMode: .hybrid,
            maxStoredNotifications: maxNotifications,
            maxNotificationAgeDays: maxAgeDays
        )
    }
}
