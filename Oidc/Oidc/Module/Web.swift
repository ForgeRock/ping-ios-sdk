// 
//  Web.swift
//  Oidc
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate
import PingBrowser
import Foundation
import PingNetwork

#if canImport(UIKit)
/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class WebModule {
    
    /// Initializes a new instance of `SessionModule`.
    public init() {}
    
    /// The module configuration for transforming the response from Journey to `Node`.
    public static let config: Module<Void> = Module.of(setup: { setup in
        
        let oidcLoginFlow: OidcWebClient = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            oidcLoginFlow.sharedContext.set(key: SharedContext.Keys.oidcIsWeb, value: true)
        }
        
        // Start the browser authorization flow. Returns the authorization code in the response.
        setup.transport { @Sendable context, request in
            let callbackURLScheme = context.flowContext.get(key: SharedContext.Keys.callbackURLSchemeKey) as? String ?? ""
            let redirectUri = context.flowContext.get(key: SharedContext.Keys.redirectUriKey) as? String
            let expectedState = context.flowContext.get(key: SharedContext.Keys.stateKey) as? String
            let oidcLoginConfig = oidcLoginFlow.config as? OidcWebClientConfig

            do {
                guard let urlString = request.url, let url = URL(string: urlString) else {
                    throw OidcError.authorizeError(message: "Browser authorization failed: URL not found")
                }
                // Ensure the redirect URI scheme is valid
                let result = try await BrowserLauncher.currentBrowser.launch(url: url, customParams: nil, browserType: oidcLoginConfig?.browserType ?? .authSession, browserMode: oidcLoginConfig?.browserMode ?? .login, callbackURLScheme: callbackURLScheme, redirectUri: redirectUri, logger: oidcLoginFlow.config.logger)

                // Validate `state` against the value sent on the authorize request (CSRF)
                // BEFORE trusting anything else on the callback — RFC 6749 §4.1.2.1 requires
                // `state` on an error response just as on a success response, so a spoofed
                // error redirect (e.g. from another app registered for the same custom URL
                // scheme) with a missing or mismatched `state` is rejected here rather than
                // surfaced as the (untrustworthy) `error`/`error_description` it carries.
                try WebModule.validateState(from: result, expected: expectedState)

                // Surface OAuth2 error redirects (e.g. `access_denied`) with their real
                // code/description instead of a generic "code not found" failure.
                if let oauthError = WebModule.extractOAuthError(from: result) {
                    throw OidcError.authorizeError(cause: oauthError, message: "Authorization failed: \(oauthError.formattedMessage)")
                }

                // Extract and verify the auth code response
                let code = try WebModule.extractCode(from: result)
                let jsonDict: [String: Any] = [
                        "code": code
                    ]
                // Return the authorization code response
                return await URLSessionHttpResponse(request: request, body: WebModule.body(code: code), httpURLResponse: HTTPURLResponse())
            } catch {
                // Errors thrown inside this `do` block are already `OidcError.authorizeError`
                // with the right `cause` (e.g. `OAuthAuthorizationError`, `BrowserError`) —
                // rethrow them unchanged rather than wrapping an `authorizeError` inside
                // another `authorizeError`. Only foreign errors get the standard wrap.
                if let authorizeError = error as? OidcError, case .authorizeError = authorizeError {
                    throw authorizeError
                }
                // Preserve the underlying error (e.g. `BrowserError.httpsCallbackUnsupportedOS`,
                // `BrowserError.invalidHTTPSRedirectConfiguration`) as `cause` so callers can
                // inspect it, rather than flattening it into the message only.
                throw OidcError.authorizeError(cause: error, message: "Browser authorization failed: \(error.localizedDescription)")
            }
        }
        
        // Transform the response to `Node`.
        setup.transform { @Sendable context, response in
            guard let json = try? response.json(),
                  let code = json[OidcClient.Constants.code] as? String
            else {
                throw OidcError.authorizeError(message: "Authorization code not found in response")
            }
            var session = EmptySession()
            session.value = code
            return SuccessNode(input: json, session: session)
        }
    })
}

extension WebModule {
    /// Extracts the redirect URI scheme from the provided redirect URI string.
    /// - Parameter redirectUri: The redirect URI string.
    /// - Returns: The scheme of the redirect URI if it is valid, otherwise nil.
    internal static func redirectURIScheme(redirectUri: String) -> String? {
        if let redirectURI = URL(string: redirectUri), let callbackURLScheme = redirectURI.scheme {
            return callbackURLScheme
        }
        return nil
    }
    
    /// Extracts the authorization code from the provided URL.
    /// - Parameter url: The URL containing the authorization code.
    /// - Returns: The authorization code if found.
    internal static func extractCode(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let code = components.queryItems?.filter({$0.name == OidcClient.Constants.code}).first?.value {
            return code
        } else {
            throw OidcError.authorizeError(message: "Authorization code not found")
        }
    }

    /// Extracts an OAuth2 error response from the authorization redirect URL, if present.
    /// Delegates to `OidcClient.extractOAuthError(from:)` (shared with the non-UIKit path).
    /// - Parameter url: The callback URL to inspect.
    /// - Returns: The parsed `OAuthAuthorizationError`, or nil if this is not an error redirect.
    internal static func extractOAuthError(from url: URL) -> OAuthAuthorizationError? {
        OidcClient.extractOAuthError(from: url)
    }

    /// Validates the `state` on the callback against the value the SDK sent on the authorize
    /// request (RFC 6749 §10.12 CSRF protection). Skipped when no expected value was recorded.
    /// Delegates to `OidcClient.validateState(from:expected:)` (shared with the non-UIKit path).
    /// - Parameters:
    ///   - url: The callback URL carrying the returned `state`.
    ///   - expected: The state value sent on the authorize request, if known.
    /// - Throws: `OidcError.authorizeError` on mismatch or when the callback carries no state
    ///   although one was sent.
    internal static func validateState(from url: URL, expected: String?) throws {
        try OidcClient.validateState(from: url, expected: expected)
    }

    /// Extracts the state from the provided URL.
    /// - Parameter url: The URL containing the state.
    /// - Returns: The state if found.
    internal static func extractState(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let state = components.queryItems?.filter({$0.name == "state"}).first?.value {
            return state
        } else {
            throw OidcError.authorizeError(message: "State not found")
        }
    }
    
    /// Builds the body data for the request.
    /// - Parameter code: The authorization code to include in the body.
    /// - Returns: The body data as `Data`.
    internal static func body(code: String) async -> Data {
        // Build a JSON dictionary with your code value
        let jsonDict: [String: Any] = [
            "code": code
        ]
        
        // Serialize to Data
        guard
            JSONSerialization.isValidJSONObject(jsonDict),
            let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: [])
        else {
            return Data()
        }
        
        return data
    }
}
#endif
