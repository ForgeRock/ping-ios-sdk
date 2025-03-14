//
//  User.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// Protocol for a User.
/// Provides methods for token management, user information retrieval, and logout.
public protocol User: Sendable {
    /// Retrieves the token for the user.
    /// - Returns: A `Result` object containing either the `Token` or an `OidcError`.
    func token() async -> Result<Token, OidcError>
    
    /// Revokes the user's token.
    func revoke() async
    
    /// Retrieves the user's information.
    /// - Parameter cache: Whether to cache the user information.
    /// - Returns: A `Result` object containing either the user information as a `UserInfo` or an `OidcError`.
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError>
    
    /// Logs out the user.
    func logout() async
}


/// A type alias representing user information as a dictionary.
public typealias UserInfo = [String: Sendable]
