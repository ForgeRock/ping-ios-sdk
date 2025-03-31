//
//  OidcClient.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOrchestrate

/// Class representing an OpenID Connect client.
/// - Property pkce: PKCE  object used for the Authorization call.
public class OidcClient {
    public var pkce: Pkce?
    private let config: OidcClientConfig
    private let logger: Logger
    
    /// OidcClient initializer.
    /// - Parameter config: The configuration for this client.
    public init(config: OidcClientConfig) {
        self.config = config
        self.logger = config.logger
    }
    
    /// OidcClient generateAuthorizeUrl.
    /// - Parameter customParams: Custom parameters to include in the authorization request.
    public func generateAuthorizeUrl(customParams: [String: String]? = nil) throws -> URL {
        var request = Request()
        self.pkce = Pkce.generate()
        request = config.populateRequest(request: request, pkce: pkce!, responseMode: OidcClient.Constants.query)
        if let customParams = customParams {
            for parameter in customParams {
                request.parameter(name: parameter.key, value: parameter.value)
            }
        }
        guard let url = request.urlRequest.url, let redirectURI = URL(string: config.redirectUri), let _ = redirectURI.scheme else {
            throw OidcError.networkError(message: "URL not found")
        }
        
        return url
    }
    
    /// Extracts the code from the URL and exchanges it for an access token.
    ///  - Parameter url: The URL to extract the code from.
    public func extractCodeAndGetToken(from url: URL) async throws -> Token {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let code = components.queryItems?.filter({$0.name == "code"}).first?.value, let pcke = self.pkce {
            let authCode = AuthCode(code: code, codeVerifier: pcke.codeVerifier)
            return try await self.exchangeToken(authCode)
        } else {
            throw OidcError.authorizeError(message: "Authorization code not found")
        }
    }
    
    /// Extract the Redirect URI scheme from the configuration
    public func redirectURIScheme() -> String? {
        if let redirectURI = URL(string: config.redirectUri), let callbackURLScheme = redirectURI.scheme {
            return callbackURLScheme
        }
        return nil
    }
    
    /// Retrieves an access token. If a cached token is available and not expired, it is returned.
    /// Otherwise, a new token is fetched with refresh token if refresh grant is available.
    /// - Returns: A Result containing the access token or an error.
    public func token() async -> Result<Token, OidcError> {
        
        do {
            try await config.oidcInitialize()
        } catch {
            return .failure((error as? OidcError) ?? OidcError.unknown(cause: error))
        }
        
        config.logger.i("Getting access token")
        do {
            if let cached = try await config.storage.get() {
                if !cached.isExpired(threshold: config.refreshThreshold) {
                    config.logger.i("Token is not expired. Returning cached token.")
                    return .success(cached)
                }
                config.logger.i("Token is expired. Attempting to refresh.")
                if let cachedefreshToken = cached.refreshToken {
                    do {
                        let refreshedToken = try await refreshToken(cachedefreshToken)
                        return .success(refreshedToken)
                    } catch {
                        config.logger.e("Failed to refresh token. Revoking token and re-authenticating.", error: error)
                        await revoke(cached)
                    }
                }
            }
            
            // Authenticate the user
            guard let agent = config.agent else {
                return .failure(OidcError.authorizeError(message: "Agent not configured"))
            }
            
            let code = try await agent.authenticate()
            let token = try await exchangeToken(code)  
            try await config.storage.save(item: token)
            return .success(token)
        } catch {
            return .failure((error as? OidcError) ?? (OidcError.authorizeError(cause: error)))
        }
    }
    
    /// Refreshes the access token.
    /// - Parameter refreshToken: The refresh token to use for refreshing the access token.
    /// - Returns: The refreshed access token.
    public func refreshToken(_ refreshToken: String) async throws -> Token {
        try await config.oidcInitialize()
        config.logger.i("Refreshing token")
        
        let params = [
            Constants.grant_type: Constants.refresh_token,
            Constants.refresh_token: refreshToken,
            Constants.client_id: config.clientId
        ]
        
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        
        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }
        
        let request = Request()
        request.url(openId.tokenEndpoint)
        request.form(formData: params)
        
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        
        try await config.storage.save(item: token)
        
        return token
    }
    
    /// Revokes the access token.
    public func revoke() async {
        await revoke(nil)
    }
    
    /// Revokes a specific access token. Best effort to revoke the token.
    /// The stored token is removed regardless of the result.
    /// - Parameter token: The access token to revoke. If null, the currently stored token is revoked.
    private func revoke(_ token: Token? = nil) async {
        var accessToken = token
        if accessToken == nil {
            accessToken = try? await config.storage.get()
        }
        if let token = accessToken {
            do {
                try await config.storage.delete()
                try await config.oidcInitialize()
            } catch {
                config.logger.e("Failed to delete token", error: error)
            }
            let t = token.refreshToken ?? token.accessToken
            let params = [
                Constants.client_id: config.clientId,
                Constants.token: t
            ]
            
            guard let httpClient = config.httpClient else {
                config.logger.e("HTTP client not found", error: nil)
                return
            }
            
            guard let openId = config.openId else {
                config.logger.e("OpenID configuration not found", error: nil)
                return
            }
            
            let request = Request()
            request.url(openId.revocationEndpoint)
            request.form(formData: params)
            do {
                let (_, _) = try await httpClient.sendRequest(request: request)
            } catch {
                config.logger.e("Failed to revoke token", error: error)
            }
        }
    }
    
    /// Ends the session. Best effort to end the session.
    /// The stored token is removed regardless of the result.
    /// - Returns:  A boolean indicating whether the session was ended successfully.
    @discardableResult
    public func endSession() async -> Bool {
        return await endSession { idToken in
            return try await self.config.agent?.endSession(idToken: idToken) ?? false
        }
    }
    
    /// Ends the session with a custom sign-off procedure.
    /// - Parameter signOff: A suspend function to perform the sign-off.
    /// - Returns: A boolean indicating whether the session was ended successfully.
    @discardableResult
    public func endSession(signOff: @escaping (String) async throws -> Bool) async -> Bool {
        do {
            try await config.oidcInitialize()
            if let accessToken = try await config.storage.get() {
                await revoke(accessToken)
                if let idToken = accessToken.idToken {
                    return try await signOff(idToken)
                }
            }
        } catch {
            config.logger.e("Failed to end session", error: error)
            return false
        }
        return true
    }
    
    /// Retrieves user information.
    /// - Returns: A Result containing the user information or an error.
    public func userinfo() async -> Result<UserInfo, OidcError> {
        do {
            try await config.oidcInitialize()
            
            guard let httpClient = config.httpClient else {
                throw OidcError.networkError(message: "HTTP client not found")
            }
            
            guard let openId = config.openId else {
                throw OidcError.unknown(message: "OpenID configuration not found")
            }
            
            switch await token() {
            case .failure(let error):
                return .failure(error)
            case .success(let token):
                let request = Request()
                request.url(openId.userinfoEndpoint)
                request.header(name: "Authorization", value: "Bearer \(token.accessToken)")
                let (data, response) = try await httpClient.sendRequest(request: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
                }
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? UserInfo ?? [:]
                return .success(json)
            }
        } catch {
            return .failure((error as? OidcError) ?? .unknown(cause: error))
        }
    }
    
    /// Exchanges an authorization code for an access token.
    /// - Parameter authCode: The authorization code to exchange.
    /// - Returns: The access token.
    private func exchangeToken(_ authCode: AuthCode) async throws -> Token {
        try await config.oidcInitialize()
        config.logger.i("Exchanging token")
        
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        
        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }
        
        var params = [
            Constants.grant_type: Constants.authorization_code,
            Constants.code: authCode.code,
            Constants.redirect_uri: config.redirectUri,
            Constants.client_id: config.clientId,
        ]
        
        if let codeVerifier = authCode.codeVerifier {
            params[Constants.code_verifier] = codeVerifier
        }
        
        let request = Request()
        request.url(openId.tokenEndpoint)
        request.form(formData: params)
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        return token
    }
    
    /// Represents various constants used in OIDC requests
    public enum Constants {
        public static let client_id = "client_id"
        public static let grant_type = "grant_type"
        public static let refresh_token = "refresh_token"
        public static let token = "token"
        public static let authorization_code = "authorization_code"
        public static let redirect_uri = "redirect_uri"
        public static let code_verifier = "code_verifier"
        public static let code = "code"
        public static let id_token_hint = "id_token_hint"
    }
}

extension OidcClientConfig {
    internal func populateRequest(
        request: Request,
        pkce: Pkce,
        responseMode: String = OidcClient.Constants.piflow
    ) -> Request {
        request.url(openId?.authorizationEndpoint ?? "")
        request.parameter(name: OidcClient.Constants.response_mode, value: responseMode)
        request.parameter(name: OidcClient.Constants.client_id, value: clientId)
        request.parameter(name: OidcClient.Constants.response_type, value: OidcClient.Constants.code)
        request.parameter(name: OidcClient.Constants.scope, value: scopes.joined(separator: " "))
        request.parameter(name: OidcClient.Constants.redirect_uri, value: redirectUri)
        request.parameter(name: OidcClient.Constants.code_challenge, value: pkce.codeChallenge)
        request.parameter(name: OidcClient.Constants.code_challenge_method, value: pkce.codeChallengeMethod)
        
        if let acr = acrValues {
            request.parameter(name: OidcClient.Constants.acr_values, value: acr)
        }
        
        if let display = display {
            request.parameter(name: OidcClient.Constants.display, value: display)
        }
        
        for (key, value) in additionalParameters {
            request.parameter(name: key, value: value)
        }
        
        if let loginHint = loginHint {
            request.parameter(name: OidcClient.Constants.login_hint, value: loginHint)
        }
        
        if let nonce = nonce {
            request.parameter(name: OidcClient.Constants.nonce, value: nonce)
        }
        
        if let prompt = prompt {
            request.parameter(name: OidcClient.Constants.prompt, value: prompt)
        }
        
        if let uiLocales = uiLocales {
            request.parameter(name: OidcClient.Constants.ui_locales, value: uiLocales)
        }
        
        return request
    }
}


extension OidcClient.Constants {
    static let response_mode = "response_mode"
    static let response_type = "response_type"
    static let scope = "scope"
    static let code_challenge = "code_challenge"
    static let code_challenge_method = "code_challenge_method"
    static let acr_values = "acr_values"
    static let display = "display"
    static let nonce = "nonce"
    static let prompt = "prompt"
    static let ui_locales = "ui_locales"
    static let login_hint = "login_hint"
    static let piflow = "pi.flow"
    static let query = "query"
}
