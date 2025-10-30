//
//  UserKey.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A struct representing a user's key.
public struct UserKey: Codable, Identifiable, Sendable {
    public var id: String { kid }
    /// The key tag.
    public let keyTag: String
    /// The user ID.
    public let userId: String
    /// The username.
    public let username: String
    /// The key ID.
    public let kid: String
    /// The authentication type.
    public let authType: DeviceBindingAuthenticationType
    /// The creation date.
    public let createdAt: Date
    
    /// Initializes a new `UserKey`.
    /// - Parameters:
    ///   - keyTag: The key tag.
    ///   - userId: The user ID.
    ///   - username: The username.
    ///   - kid: The key ID.
    ///   - authType: The authentication type.
    public init(keyTag: String, userId: String, username: String, kid: String, authType: DeviceBindingAuthenticationType) {
        self.keyTag = keyTag
        self.userId = userId
        self.username = username
        self.kid = kid
        self.authType = authType
        self.createdAt = Date()
    }
}
