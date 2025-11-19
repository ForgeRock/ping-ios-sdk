//
//  PushDeviceToken.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents a device token for push notifications.
///
/// A device token is a unique identifier assigned by the Apple Push Notification service (APNs)
/// to a specific device and application combination. This token is required for sending push
/// notifications to the device.
///
/// ## Token Management
///
/// Device tokens should be updated whenever:
/// - The app is installed or reinstalled
/// - The device is restored from backup
/// - The user updates iOS to a new major version
/// - The token changes (APNs may regenerate tokens periodically)
///
/// ## Security Considerations
///
/// - Tokens are device and app-specific
/// - Tokens should be stored securely in the Keychain
/// - Tokens should be sent to the server over secure connections only
/// - Expired or invalid tokens should be removed from the server
///
/// ## Usage Example
///
/// ```swift
/// // When receiving a device token from APNs
/// func application(_ application: UIApplication,
///                  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
///     let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
///     let pushDeviceToken = PushDeviceToken(token: tokenString)
///     // Store and register with server
/// }
/// ```
public struct PushDeviceToken: Codable, Identifiable, Sendable, Equatable {
    
    // MARK: - Properties
    
    /// The unique device token string from APNs.
    ///
    /// This is typically a 64-character hexadecimal string representing the device token
    /// provided by Apple Push Notification service.
    public let token: String
    
    /// The date when this token was created or updated.
    ///
    /// This timestamp helps track when the token was last registered and can be used
    /// to determine if the token needs to be refreshed.
    public let createdAt: Date
    
    /// Unique identifier for this token record.
    public let id: String
    
    // MARK: - Initialization
    
    /// Creates a new device token instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - token: The device token string from APNs.
    ///   - createdAt: The timestamp when the token was created (defaults to current date).
    public init(id: String = UUID().uuidString, token: String, createdAt: Date = Date()) {
        self.id = id
        self.token = token
        self.createdAt = createdAt
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case token
        case createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        token = try container.decode(String.self, forKey: .token)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(token, forKey: .token)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: PushDeviceToken, rhs: PushDeviceToken) -> Bool {
        return lhs.token == rhs.token
    }
}
