//
//  Oidc.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOidc
import PingOrchestrate

/// A module that integrates OIDC capabilities into the Journey workflow.
public class OidcModule {
    
    /// Initializes a new instance of `OidcModule`.
    public init() {}
    
    /// The configuration for the OIDC module.
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let journeyFlow: Journey = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            // propagate the configuration from workflow to the module
            config.httpClient = journeyFlow.config.httpClient
            config.logger = journeyFlow.config.logger
            // global context
            journeyFlow.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: config)
            //Override the agent setting
            config.updateAgent(DefaultAgent())
            try await config.oidcInitialize()
        }
        
        // Handles success of the module.
        setup.success { @Sendable context, success in
            let cloneConfig: OidcClientConfig = config.clone()
            let journeyConfig: JourneyConfig? = journeyFlow.config as? JourneyConfig
            let flowPkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            let agent = CreateAgent(session: success.session, pkce: flowPkce, cookieName: journeyConfig?.cookie ?? JourneyConstants.cookie)
            cloneConfig.updateAgent(agent)
            
            let oidcuser: User = OidcUser(config: cloneConfig)
            let prepareUser = UserDelegate(journey: journeyFlow, user: oidcuser, session: success.session)
            journeyFlow.sharedContext.set(key: SharedContext.Keys.userKey, value: prepareUser)
            
            return SuccessNode(input: success.input, session: success.session)
        }
        
        // Handles sign off of the module.
        setup.signOff { @Sendable request in
            _ = await OidcClient(config: config).endSession { idToken in
                return true
            }
            
            return request
        }
    }
}

extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    static let pkceKey = "com.pingidentity.journey.PKCE"
    
    /// The key used to store the user in the shared context.
    static let userKey = "com.pingidentity.journey.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    static let oidcClientConfigKey = "com.pingidentity.journey.OidcClientConfig"
}
