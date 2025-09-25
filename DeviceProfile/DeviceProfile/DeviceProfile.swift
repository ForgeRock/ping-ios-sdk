//
//  DeviceProfile.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney

// MARK: - DeviceProfile

/// Main entry point for the DeviceProfile SDK.
///
/// This class provides the primary interface for integrating device profile
/// collection capabilities into Ping Identity journey flows. It handles
/// registration of callback types and provides the foundation for device
/// fingerprinting and profiling functionality.
///
/// ## Integration
/// Call `registerCallbacks()` during application startup to enable
/// device profile collection in authentication journeys.
///
/// ## Usage Example
/// ```swift
/// // In AppDelegate or SceneDelegate
/// DeviceProfile.registerCallbacks()
/// ```
///
/// ## Architecture
/// The DeviceProfile system consists of several key components:
/// - **Collectors**: Gather specific types of device information
/// - **Callback**: Handles server communication and configuration
/// - **Config**: Controls what data is collected and how
/// - **Results**: Structured data containing device profile information
@objc
class DeviceProfile: NSObject {
    
    /// Registers the DeviceProfile callback with the Ping Journey framework.
    ///
    /// This method must be called during application initialization to enable
    /// device profile collection capabilities within authentication journeys.
    /// It registers the DeviceProfileCallback class with the callback registry
    /// using the standard device profile callback identifier.
    ///
    /// ## Registration Process
    /// 1. Registers DeviceProfileCallback class with CallbackRegistry
    /// 2. Associates it with the "DeviceProfileCallback" type identifier
    /// 3. Enables server-initiated device profiling in journey flows
    ///
    /// ## Timing
    /// - Must be called before any journey that uses device profiling
    /// - Typically called in AppDelegate.application(_:didFinishLaunchingWithOptions:)
    /// - Registration is idempotent - safe to call multiple times
    ///
    /// ## Example Integration
    /// ```swift
    /// @UIApplicationMain
    /// class AppDelegate: UIResponder, UIApplicationDelegate {
    ///     func application(_ application: UIApplication,
    ///                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///         // Register device profiling capability
    ///         DeviceProfile.registerCallbacks()
    ///         return true
    ///     }
    /// }
    /// ```
    @objc
    public static func registerCallbacks() {
        CallbackRegistry.shared.register(
            type: JourneyConstants.deviceProfileCallback,
            callback: DeviceProfileCallback.self
        )
    }
}

// MARK: - JourneyConstants Extension

extension JourneyConstants {
    /// Constant identifier for the device profile callback type.
    /// This value is used by the server to indicate that device profiling
    /// is required during the authentication journey.
    public static let deviceProfileCallback = "DeviceProfileCallback"
}

/// Represents various constants used in DeviceProfile module
public enum DeviceProfileConstants {
    public static let unknown = "Unknown"
    public static let navigator_userAgent = "navigator.userAgent"
    public static let userAgent = "userAgent"
    
}
