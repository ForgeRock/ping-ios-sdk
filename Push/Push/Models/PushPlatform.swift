//
//  PushPlatform.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Enum representing the different push notification platforms supported by the SDK.
///
/// Each platform has its own specific implementation for handling push notifications,
/// including message parsing, registration, and response sending. The platform determines
/// which `PushHandler` implementation will be used to process notifications.
///
/// ## Extensibility
///
/// While the SDK currently supports PingAM as the primary platform, the architecture
/// is designed to support additional platforms in the future. Custom platform implementations
/// can be added by implementing the `PushHandler` protocol and registering them with
/// the `PushConfiguration`.
///
/// ## Standards Compliance
///
/// - **PingAM**: Implements the Ping Identity Access Management push authentication protocol
public enum PushPlatform: String, CaseIterable, Codable, Sendable {
    
    /// Ping Identity Access Management platform.
    ///
    /// This platform implements the push authentication protocol used by Ping Identity
    /// Access Management (formerly ForgeRock Access Management). It supports:
    /// - Push registration via QR code (pushauth:// and mfauth:// schemes)
    /// - Multiple push types (default, challenge, biometric)
    /// - JWT-based message signing and verification
    /// - Device token management and updates
    ///
    /// **Message Format:**
    /// PingAM push notifications typically use JWT tokens with specific claims for
    /// authentication context, challenge data, and expiration information.
    ///
    /// **Characteristics:**
    /// - Uses JWT for secure message signing
    /// - Supports registration, authentication, and device token updates
    /// - Compatible with ForgeRock Authenticator protocol
    case pingAM = "pingam"
    
    /// Creates a PushPlatform from a string representation.
    ///
    /// This method allows parsing platform types from strings in a case-insensitive manner,
    /// making it easier to work with data from various sources (APIs, URIs, configuration).
    ///
    /// - Parameter string: The string representation (case-insensitive).
    /// - Returns: The corresponding PushPlatform.
    /// - Throws: `PushError.invalidPlatform` if the string doesn't match any known platform.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let platform = try PushPlatform.fromString("PINGAM") // Returns .pingAM
    /// ```
    public static func fromString(_ string: String) throws -> PushPlatform {
        switch string.lowercased() {
        case "pingam", "ping_am", "ping-am":
            return .pingAM
        default:
            throw PushError.invalidPlatform(string)
        }
    }
}
