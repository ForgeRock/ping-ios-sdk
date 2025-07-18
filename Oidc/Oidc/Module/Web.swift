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

internal let IS_WEB = "IS_WEB"
internal let PARAMETERS = "PARAMETERS"
/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class WebModule {
    
    /// Initializes a new instance of `SessionModule`.
    public init() {}
    
    /// The module configuration for transforming the response from Journey to `Node`.
    public static let config: Module<Void> = Module.of(setup: { setup in
        
        let oidcLoginFlow: OidcWeb = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            oidcLoginFlow.sharedContext.set(key: IS_WEB, value: true)
        }
        
        setup.start { @Sendable context, request in
            let parameters = oidcLoginFlow.sharedContext.get(key: PARAMETERS) as? [String: String] ?? [:]
            for parameter in parameters {
                request.parameter(name: parameter.key, value: parameter.value)
            }
            return request
        }
        
        setup.transport { @Sendable context, request in
            let flowPkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            let callbackURLScheme = context.flowContext.get(key: SharedContext.Keys.callbackURLSchemeKey) as? String ?? ""
            let oidcLoginConfig = oidcLoginFlow.config as? OidcWebConfig
            await oidcLoginFlow.user()?.revoke()
            let pkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            do {
                guard let url = request.urlRequest.url else {
                    throw OidcError.authorizeError(message: "Browser authorization failed: URL not found")
                }
                let launcher = await BrowserLauncher()
                let result = try await launcher.launch(url: url, browserType: oidcLoginConfig?.browserType ?? .authSession, browserMode: oidcLoginConfig?.browserMode ?? .login, callbackURLScheme: callbackURLScheme)
                
                await BrowserLauncher.currentBrowser.reset()
                
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
        
        setup.transform { @Sendable context, response in
            guard let httpResponse = response as? HttpResponse,
                    let json = try? httpResponse.json(data: response.data),
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
    
    internal static func redirectURIScheme(redirectUri: String) -> String? {
        if let redirectURI = URL(string: redirectUri), let callbackURLScheme = redirectURI.scheme {
            return callbackURLScheme
        }
        return nil
    }
    
    internal static func extractCode(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let code = components.queryItems?.filter({$0.name == OidcClient.Constants.code}).first?.value {
            return code
        } else {
            throw OidcError.authorizeError(message: "Authorization code not found")
        }
    }
    
    internal static func extractState(from url: URL) throws -> String {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let state = components.queryItems?.filter({$0.name == "state"}).first?.value {
            return state
        } else {
            throw OidcError.authorizeError(message: "State not found")
        }
    }
    
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
