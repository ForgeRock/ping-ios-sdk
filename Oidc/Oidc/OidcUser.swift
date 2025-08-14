//
//  OidcUser.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// Class for an OIDC User
public class OidcUser: User, @unchecked Sendable {
    
    /// The user information.
    private var userinfo: UserInfo?
    /// The OIDC client used to interact with the OIDC provider.
    private let oidcClient: OidcClient
    
    /// OidcUser initializer
    /// - Parameter config: The configuration for the OIDC client.
    public init(config: OidcClientConfig) {
        self.oidcClient = OidcClient(config: config)
    }
    
    /// Gets the token for the user.
    /// - Returns: The token for the user.
    public func token() async -> Result<Token, OidcError> {
        return await oidcClient.token()
    }
    
    /// Method to refresh the user token.
    /// - Note: This method retrieves the current token and attempts to refresh it using the refresh token.
    /// - Returns: A Result containing the refreshed Token or an OidcError.
    public func refresh() async -> Result<Token, OidcError> {
        let token = await self.token()
        if case .success(let data) = token, let refreshToken = data.refreshToken {
            do {
                let refreshedToken = try await oidcClient.refreshToken(refreshToken)
                return .success(refreshedToken)
            } catch {
                return .failure(OidcError.authorizeError(cause: error, message: error.localizedDescription))
            }
        } else {
            return .failure(OidcError.unknown(cause: nil, message: "Failed to get the refresh token"))
        }
    }
    
    /// Revokes the user's token.
    public func revoke() async {
        await oidcClient.revoke()
    }
    
    /// Gets the user information.
    /// - Parameter cache: Whether to cache the user information.
    /// - Returns: The user information.
    public func userinfo(cache: Bool = true) async -> Result<UserInfo, OidcError> {
        if let userinfo = self.userinfo, cache {
            return .success(userinfo)
        }
        let result = await oidcClient.userinfo()
        if case .success(let data) = result, cache {
            self.userinfo = data
        }
        return result
    }
    
    /// Logs out the user.
    public func logout() async {
        _ = await oidcClient.endSession()
    }
}
