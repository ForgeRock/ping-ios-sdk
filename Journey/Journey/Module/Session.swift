//
//  Session.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingStorage

public class SessionModule {
    
    /// Initializes a new instance of `SessionModule`.
    public init() {}
    
    static let config: Module<SessionConfig> = Module.of ({ SessionConfig() }) { setup in
        
        let config: SessionConfig = setup.config
        let journeyFlow: Journey = setup.workflow
        
        /// Set the session config in the shared context
        setup.initialize { @Sendable in
            journeyFlow.sharedContext.set(key: SharedContext.Keys.sessionConfigKey, value: config)
        }
        /// Start handler for the session module
        setup.start { @Sendable context, request in
            if let token = await journeyFlow.session(), let journeyConfig = journeyFlow.config as? JourneyConfig {
                request.header(name: journeyConfig.cookie, value: token.value)
            }
            return request
        }
        /// Next handler for the session module
        setup.next { @Sendable context, _, request in
            if let token = await journeyFlow.session(), let journeyConfig = journeyFlow.config as? JourneyConfig {
                request.header(name: journeyConfig.cookie, value: token.value)
            }
            return request
        }
        /// Success handler for the session module
        setup.success { @Sendable context, request in
            if !request.session.value.isEmpty, let token = request.session as? SSOTokenImpl {
                try await config.storage.save(item: token)
            }
            return request
        }
        /// Sign off handler for the session module
        setup.signOff { @Sendable request in
            if let ssoToken = await journeyFlow.session(), let journeyConfig = journeyFlow.config as? JourneyConfig {
                request.url("\(journeyConfig.serverUrl ?? "")/json/realms/\(journeyConfig.realm)/sessions")
                request.parameter(name: "_action", value: "logout")
                request.header(name: journeyConfig.cookie, value: ssoToken.value)
                request.header(name: JourneyConstants.acceptApiVersion, value: JourneyConstants.resource31)
                request.body(body: [:]) // assume empty body
                await journeyFlow.deleteSession()
                return request
            } else {
                return request
            }
        }
    }
}

extension Workflow {
    /// Retrieves the SSOToken from the session config in sharedContext
    func session() async -> SSOToken? {
        let config = sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig
        return try? await config?.storage.get()
    }
    
    /// Deletes the stored SSOToken from the session config in sharedContext
    public func deleteSession() async {
        let config = sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig
        try? await config?.storage.delete()
    }
}

