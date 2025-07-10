//
//  Agent.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOidc
import PingOrchestrate

/// An agent that handles the creation of an authentication session.
/// This agent is used to initiate the authentication process for a user.
/// It implements the `Agent` protocol and provides methods to configure the agent, end the session, and authorize the user.
internal final class CreateAgent: Agent, Sendable {
    typealias T = Void
    let cookieName: String
    let session: Session
    let pkce: Pkce?
    nonisolated(unsafe) var used = false
    
    /// Initializes a new `CreateAgent` instance.
    /// - Parameters:
    /// - session: The session to use for authentication.
    /// - pkce: The PKCE (Proof Key for Code Exchange) object, if available.
    /// - cookieName: The name of the cookie to use for the session.
    init(session: Session, pkce: Pkce?, cookieName: String) {
        self.session = session
        self.pkce = pkce
        self.cookieName = cookieName
    }
    
    /// Provides an empty configuration for the `CreateAgent`.
    func config() -> () -> T {
        return {}
    }
    
    /// Ends the session with the OpenID Connect provider.
    func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool {
        // Since we don't have the Session token, let Journey handle the sign-off
        return true
    }
    
    /// Authorizes the agent with the OpenID Connect provider.
    /// Before returning the `AuthCode`, the agent should verify the response from the OpenID Connect provider.
    /// - Parameter oidcConfig: The configuration for the OpenID Connect client.
    /// - Returns: `AuthCode` instance
    /// - Throws: An `OidcError` if the authorization fails.
    func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode {
        // We don't get the state; The state may not be returned since this is primarily for
        // CSRF in redirect-based interactions, and pi.flow doesn't use redirect.
        guard !session.value.isEmpty else {
            throw OidcError.authorizeError(message: "Please start Journey to authenticate.")
        }
        guard !used else {
            throw OidcError.authorizeError(message: "Auth code already used, please start Journey again.")
        }
        
        let pkce = Pkce.generate()
        let config = oidcConfig.oidcClientConfig
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        
        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }
        
        let params: [String: String] = [
            JourneyConstants.response_type: JourneyConstants.code,
            JourneyConstants.redirect_uri: config.redirectUri,
            JourneyConstants.client_id: config.clientId,
            JourneyConstants.scope: config.scopes.joined(separator: " "),
            JourneyConstants.state: pkce.state,
            JourneyConstants.code_challenge: pkce.codeChallenge,
            JourneyConstants.code_challenge_method: pkce.codeChallengeMethod
        ]

        let request = Request()
        
        request.url(openId.authorizationEndpoint)
        for (name, value) in params {
            request.parameter(name: name, value: value)
        }
        request.header(name: JourneyConstants.acceptApiVersion, value: JourneyConstants.resource21Protocol10)
        request.header(name: cookieName, value: session.value)
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 302 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
        }
        
        guard let locationHeader = httpResponse.value(forHTTPHeaderField: JourneyConstants.location),
           let urlComponents = URLComponents(string: locationHeader),
           let authCode = urlComponents.queryItems?.first(where: { $0.name == JourneyConstants.code })?.value else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Code not found in redirect")
        }
        
        used = true
        return session.authCode(pkce: pkce, code: authCode)
    }
}


extension Session {
    /// Creates an `AuthCode` from the session and PKCE parameters.
    /// - Parameters:
    /// - pkce: The PKCE parameters used for the authorization code exchange.
    /// - code: The authorization code received from the OpenID Connect provider.
    /// - Returns: An `AuthCode` instance containing the code and code verifier.
    func authCode(pkce: Pkce?, code: String) -> AuthCode {
        // parse the response and return the auth code
        return AuthCode(code: code, codeVerifier: pkce?.codeVerifier)
    }
}
