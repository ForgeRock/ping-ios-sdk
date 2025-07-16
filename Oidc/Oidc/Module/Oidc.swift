// 
//  Oidc.swift
//  Oidc
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingBrowser

/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class OidcModule {
    
    /// Initializes a new instance of `OidcModule`.
    public init() {}
    
    /// The configuration for the OIDC module.
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let oidcLoginFlow: OidcWeb = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            // propagate the configuration from workflow to the module
            config.httpClient = oidcLoginFlow.config.httpClient
            config.logger = oidcLoginFlow.config.logger
            // global context
            oidcLoginFlow.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: config)
            //Override the agent setting
            config.updateAgent(DefaultAgent())
            
            
            try await config.oidcInitialize()
        }
        
        // Starts the module.
        setup.start { @Sendable context, request in
            // When user starts the flow again, revoke previous token if exists
            let flowPkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            let oidcLoginConfig = oidcLoginFlow.config as? OidcWebConfig
            await oidcLoginFlow.user()?.revoke()
            let pkce = Pkce.generate()
            context.flowContext.set(key: SharedContext.Keys.pkceKey, value: pkce)
            config.updateAgent(BrowserAgent(config: BrowserConfig(browserType: oidcLoginConfig?.browserType ?? .authSession, browserMode: oidcLoginConfig?.browserMode ?? .login), pkce: pkce))
            return config.populateRequest(request: request, pkce: pkce)
        }
        
        // Handles success of the module.
        setup.success { @Sendable context, success in
            let oidcuser: User = OidcUser(config: config)
            let _ = await oidcuser.token()
            let prepareUser = UserDelegate(oidcLogin: oidcLoginFlow, user: oidcuser, session: success.session)
            oidcLoginFlow.sharedContext.set(key: SharedContext.Keys.userKey, value: prepareUser)
            let _ = oidcLoginFlow.sharedContext.removeValue(forKey: SharedContext.Keys.pkceKey)
            return SuccessNode(session: prepareUser)
        }
        
        // Handles sign off of the module.
        setup.signOff { @Sendable request in
            request.url(config.openId?.endSessionEndpoint ?? "")
            
            _ = await OidcClient(config: config).endSession { idToken in
                request.parameter(name: OidcClient.Constants.id_token_hint, value: idToken)
                request.parameter(name: OidcClient.Constants.client_id, value: config.clientId)
                return true
            }
            
            return request
        }
    }
}

extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    public static let pkceKey = "com.pingidentity.oidcLogin.PKCE"
    
    /// The key used to store the user in the shared context.
    public static let userKey = "com.pingidentity.oidcLogin.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    public static let oidcClientConfigKey = "com.pingidentity.oidcLogin.OidcClientConfig"
}
