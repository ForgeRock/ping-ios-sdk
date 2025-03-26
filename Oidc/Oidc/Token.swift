//
//  Token.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct representing an OIDC token.
public struct Token: Codable, Sendable {
    /// The access token used for authentication.
    public let accessToken: String
    /// The type of token.
    public let tokenType: String?
    /// The scope of access granted by the token.
    public let scope: String?
    /// The duration of the token's validity in seconds
    public let expiresIn: Int64
    /// The refresh token used to obtain a new access token.
    public let refreshToken: String?
    /// The ID token
    public let idToken: String?
    /// The exact timestamp (in seconds since 1970) when the token expires.
    public let expiresAt: Int64
    
    /// Initializes a new instance of `Token`.
    /// - Parameters:
    ///   - accessToken: The access token string.
    ///   - tokenType: The type of token.
    ///   - scope: The scope of access granted by the token.
    ///   - expiresIn: The duration (in seconds) for which the token is valid.
    ///   - refreshToken: The refresh token string (optional).
    ///   - idToken: The ID token string (optional).
    public init(accessToken: String, tokenType: String?, scope: String?, expiresIn: Int64, refreshToken: String?, idToken: String?) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = Int64(Date().timeIntervalSince1970) + expiresIn
    }
    
    /// A Boolean value indicating whether the token has expired.
    /// - Returns: `true` if the current time is greater than or equal to the token's expiry time; otherwise, `false`.
    public var isExpired: Bool {
        return Int64(Date().timeIntervalSince1970) >= expiresAt
    }
    
    /// Checks if the token will expire within a specified threshold.
    /// - Parameter threshold: The threshold duration (in seconds) to check for expiration.
    /// - Returns: `true` if the token will expire within the threshold; otherwise, `false`.
    public func isExpired(threshold: Int64) -> Bool {
        return Int64(Date().timeIntervalSince1970) >= expiresAt - threshold
    }
    
    /// Decodes a `Token` instance from a decoder.
    /// - Parameter decoder: The decoder instance used for decoding.
    /// - Throws: An error if decoding fails.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        expiresIn = try container.decode(Int64.self, forKey: .expiresIn)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        idToken = try container.decodeIfPresent(String.self, forKey: .idToken)
        expiresAt = try container.decodeIfPresent(Int64.self, forKey: .expiresAt) ?? Int64(Date().timeIntervalSince1970) + expiresIn
    }
    
    /// Encodes the `Token` instance to an encoder.
    /// - Parameter encoder: The encoder instance used for encoding.
    /// - Throws: An error if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(scope, forKey: .scope)
        try container.encode(expiresIn, forKey: .expiresIn)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(idToken, forKey: .idToken)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}


/// Define CodingKeys for the AccessToken struct
extension Token {
    /// Coding keys used for encoding and decoding the `Token` struct.
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresAt = "expires_at"
    }
}


extension Token: CustomStringConvertible {
    /// A textual representation of the `Token` instance.
    public var description: String {
        "isExpired: \(isExpired)\n access_token: \(self.accessToken)\n refresh_token: \(refreshToken ?? "nil")\n id_token: \(idToken ?? "nil")\n token_type: \(tokenType ?? "nil")\n scope: \(scope ?? "nil")\n expires_in: \(String(describing: expiresIn))\n expires_at: \(String(describing: Date(timeIntervalSince1970: TimeInterval(expiresAt))))"
    }
}
