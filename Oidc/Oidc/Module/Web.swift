// 
//  Web.swift
//  Oidc
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import PingOrchestrate
import PingBrowser
import Foundation

/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class WebModule {
    
    /// Initializes a new instance of `SessionModule`.
    public init() {}
    
    /// The module configuration for transforming the response from Journey to `Node`.
    public static let config: Module<Void> = Module.of(setup: { setup in
        
        let oidcLoginFlow: OidcWeb = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            oidcLoginFlow.sharedContext.set(key: SharedContext.Keys.oidcIsWeb, value: true)
        }
        
        // Start the browser authorization flow. Returns the authorization code in the response.
        setup.transport { @Sendable context, request in
            let callbackURLScheme = context.flowContext.get(key: SharedContext.Keys.callbackURLSchemeKey) as? String ?? ""
            let oidcLoginConfig = oidcLoginFlow.config as? OidcWebConfig
            
            do {
                guard let url = request.urlRequest.url else {
                    throw OidcError.authorizeError(message: "Browser authorization failed: URL not found")
                }
                // Ensure the redirect URI scheme is valid
                let result = try await BrowserLauncher.currentBrowser.launch(url: url, customParams: nil, browserType: oidcLoginConfig?.browserType ?? .authSession, browserMode: oidcLoginConfig?.browserMode ?? .login, callbackURLScheme: callbackURLScheme)
                
                // Extract and verify the auth code response
                let code = try WebModule.extractCode(from: result)
                let jsonDict: [String: Any] = [
                        "code": code
                    ]
                // Return the authorization code response
                return await HttpResponse(data: WebModule.body(code: code), response: URLResponse())
            } catch {
                throw OidcError.authorizeError(message: "Browser authorization failed: \(error.localizedDescription)")
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
