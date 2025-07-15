//
//  Browser.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingBrowser

/// Configuration for the BrowserAgent
public struct BrowserConfig: Sendable {
    /// The browser configuration
    public let browserType: BrowserType
    
    public let browserMode: BrowserMode
    
    /// Initialize with a BrowserConfiguration
    /// - Parameter browserConfig: The browser configuration
    public init(browserType: BrowserType = .authSession, browserMode: BrowserMode = .login) {
        self.browserType = browserType
        self.browserMode = browserMode
    }
}

/// An implementation of the Agent protocol that uses the PingBrowser module
/// for authorization with an OpenID Connect provider.
public final class BrowserAgent: Agent {
    
    public typealias T = BrowserConfig
    
    private let browserConfig: BrowserConfig
    private let pkce: Pkce
    
    /// Initialize the BrowserAgent with a configuration
    /// - Parameter config: The browser configuration
    public init(config: BrowserConfig = BrowserConfig(), pkce: Pkce) {
        self.browserConfig = config
        self.pkce = pkce
    }
    
    /// Provides the configuration object for the BrowserAgent
    /// - Returns: A function that returns the BrowserConfig
    public func config() -> () -> BrowserConfig {
        return { self.browserConfig }
    }
    
    /// Authorize the BrowserAgent with the OpenID Connect provider
    /// This implementation uses the PingBrowser module to handle the authorization flow
    /// - Parameter oidcConfig: The configuration for the OpenID Connect client
    /// - Returns: AuthCode instance containing authorization information
    public func authorize(oidcConfig: OidcConfig<BrowserConfig>) async throws -> AuthCode {
        // Create a browser launcher with the configuration
        let launcher = await BrowserLauncher()
        
        // Set up the authorization request parameters
        let clientConfig = oidcConfig.oidcClientConfig
        
        // Create the authorization URL
        guard let authUrl = URL(string: clientConfig.openId?.authorizationEndpoint ?? "") else {
            throw OidcError.authorizeError(message: "Invalid authorization endpoint URL")
        }
        
        // Build the authorization parameters
        var authParams: [String: String] = [
            "client_id": clientConfig.clientId,
            "redirect_uri": clientConfig.redirectUri,
            "response_type": "code",
            "scope": clientConfig.scopes.joined(separator: " "),
            "state": clientConfig.state ?? ""
        ]
        
        // Add optional parameters if available
        if let nonce = clientConfig.nonce {
            authParams["nonce"] = nonce
        }
        
        authParams["code_challenge"] = pkce.codeChallenge
        authParams["code_challenge_method"] = pkce.codeChallengeMethod
        
        
        // Add any additional parameters
        for (key, value) in clientConfig.additionalParameters {
            authParams[key] = value
        }
        
        // Perform the authorization
        do {
            let callbackURLScheme = URL(string: clientConfig.redirectUri)?.scheme ?? ""
            let result = try await launcher.launch(url: authUrl, customParams: authParams, browserType: browserConfig.browserType, browserMode: browserConfig.browserMode, callbackURLScheme: callbackURLScheme)
            
            await BrowserLauncher.currentBrowser.reset()
            
            // Extract and verify the auth code response
            let code = try clientConfig.extractCode(from: result)
            
            //let state = try clientConfig.extractState(from: result)
            
            // Return the authorization code
            return AuthCode(code: code, codeVerifier: pkce.codeVerifier)
        } catch {
            throw OidcError.authorizeError(message: "Browser authorization failed: \(error.localizedDescription)")
        }
    }
    
    /// End the session with the OpenID Connect provider
    /// - Parameters:
    ///   - oidcConfig: The configuration for the OpenID Connect client
    ///   - idToken: The ID token used to end the session
    /// - Returns: A boolean indicating whether the session was successfully ended
    @discardableResult
    public func endSession(oidcConfig: OidcConfig<BrowserConfig>, idToken: String) async throws -> Bool {
        return true // BrowserAgent does not handle session termination
    }
}
extension OidcClientConfig {
    
    internal func redirectURIScheme() -> String? {
        if let redirectURI = URL(string: redirectUri), let callbackURLScheme = redirectURI.scheme {
            return callbackURLScheme
        }
        return nil
    }
    
    internal func extractCode(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let code = components.queryItems?.filter({$0.name == "code"}).first?.value {
            return code
        } else {
            throw OidcError.authorizeError(message: "Authorization code not found")
        }
    }
    
    internal func extractState(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let state = components.queryItems?.filter({$0.name == "state"}).first?.value {
            return state
        } else {
            throw OidcError.authorizeError(message: "State not found")
        }
    }
}
