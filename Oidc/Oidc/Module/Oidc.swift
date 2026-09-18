// 
//  Oidc.swift
//  Oidc
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingBrowser
import PingNetwork

/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class OidcModule {
    
    /// Initializes a new instance of `OidcModule`.
    public init() {}
    
    /// The configuration for the OIDC module.
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let oidcLoginFlow: OidcWebClient = setup.workflow
        
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
            let oidcLoginConfig = oidcLoginFlow.config as? OidcWebClientConfig
            await oidcLoginFlow.user()?.revoke()
            let pkce = Pkce.generate()
            context.flowContext.set(key: SharedContext.Keys.pkceKey, value: pkce)
            let url = URL(string: config.redirectUri)
            context.flowContext.set(key: SharedContext.Keys.callbackURLSchemeKey, value: url?.scheme ?? "https")
            context.flowContext.set(key: SharedContext.Keys.redirectUriKey, value: config.redirectUri)

            let parameters = oidcLoginFlow.sharedContext.get(key: SharedContext.Keys.oidcParameters) as? [String: String] ?? [:]

            var extraParameters: [String: String] = [:]
            if let authorizationDetails = oidcLoginFlow.sharedContext.get(key: SharedContext.Keys.oidcAuthorizationDetails) as? [AuthorizationDetail],
               !authorizationDetails.isEmpty {
                extraParameters[OidcClient.Constants.authorization_details] = try AuthorizationDetail.wireValue(authorizationDetails)
            }
            // Thread an integrator-supplied `state` override through the SAME at-most-once
            // slot `buildAuthorizeParams` already gives `authorization_details`, instead of
            // appending it a second time onto the front-channel URL post-hoc: `setParameter`
            // only ever appends (never overwrites), so two `state` query items would rely on
            // the AS reading the last duplicate — unspecified behavior — and, under PAR, a
            // post-hoc append never reached the PAR POST body at all. Routing it through
            // `extraParameters` fixes both: `buildAuthorizeParams` emits `state` exactly once,
            // on the front channel AND in the PAR body.
            if let integratorState = parameters[OidcClient.Constants.state] {
                extraParameters[OidcClient.Constants.state] = integratorState
            }

            // Recorded for the Web module's callback state validation (CSRF check) — matches
            // EXACTLY what `buildAuthorizeParams` emits (same precedence, same fallback),
            // regardless of whether PAR is enabled.
            let effectiveState = extraParameters[OidcClient.Constants.state] ?? config.state ?? pkce.state
            context.flowContext.set(key: SharedContext.Keys.stateKey, value: effectiveState)

            let oidcRequest = try await config.populateRequest(request: request, pkce: pkce, responseMode: "", extraParameters: extraParameters)

            // Any OTHER additionalParameters keys still apply post-populateRequest — documented
            // legacy pitfall: they leak onto the front-channel URL even under PAR. `state` and
            // `authorization_details` are excluded here: both are threaded through the
            // at-most-once `extraParameters` slot above and already emitted exactly once by
            // `buildAuthorizeParams` (front channel and, for PAR, the PAR POST body).
            for parameter in parameters where parameter.key != OidcClient.Constants.state && parameter.key != OidcClient.Constants.authorization_details {
                oidcRequest.setParameter(name: parameter.key, value: parameter.value)
            }

            return oidcRequest
        }
        
        // Handles success of the module.
        setup.success { @Sendable context, success in
            let clonedConfig = config.clone()
            let oidcuser: User = OidcUser(config: clonedConfig)
            let agent = agent(session: success.session, pkce: context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce)
            clonedConfig.updateAgent(agent)
            let _ = await oidcuser.token()
            let prepareUser = UserDelegate(oidcLogin: oidcLoginFlow, user: oidcuser, session: success.session)
            oidcLoginFlow.sharedContext.set(key: SharedContext.Keys.userKey, value: prepareUser)
            
            return SuccessNode(session: prepareUser)
        }
        
        // Handles sign off of the module.
        setup.signOff { @Sendable request in
            var request = request
            let isWeb = oidcLoginFlow.sharedContext.get(key: SharedContext.Keys.oidcIsWeb) as? Bool ?? false
            if isWeb, let endSessionUrl = config.openId?.pingEndsessionEndpoint {
                request.url = endSessionUrl
            } else {
                request.url = config.openId?.endSessionEndpoint ?? ""
            }
                
            _ = await OidcClient(config: config).endSession { idToken in
                request.setParameter(name: OidcClient.Constants.id_token_hint, value: idToken)
                request.setParameter(name: OidcClient.Constants.client_id, value: config.clientId)
                return true
            }
            
            return request
        }
    }
}

// MARK: – Swift equivalent of `agent(...)`
internal func agent(session: Session, pkce: Pkce?) -> AuthAgent {
    return AuthAgent(session: session, pkce: pkce)
}

internal final class AuthAgent: Agent, @unchecked Sendable {
    private let session: Session
    private let pkce: Pkce?
    private var used = false

    init(session: Session, pkce: Pkce?) {
        self.session = session
        self.pkce = pkce
    }

    func config() -> () -> Void {
        return {}
    }

    func authorize(oidcConfig: OidcConfig<Void>) async throws -> AuthCode {
        guard !session.value.isEmpty else {
            throw AuthorizeError.missingAuthCode
        }

        guard !used else {
            throw AuthorizeError.codeAlreadyUsed
        }

        used = true
        return session.authCode(using: pkce)
    }

    func endSession(oidcConfig: OidcConfig<Void>, idToken: String) async throws -> Bool {
        // Let the flow handle sign-off since we don't have the session token here
        return true
    }
}

// MARK: – Swift equivalent of `Session.authCode(...)`
internal extension Session {
    func authCode(using pkce: Pkce?) -> AuthCode {
        return AuthCode(code: value, codeVerifier: pkce?.codeVerifier)
    }
}

// MARK: – Error types
public enum AuthorizeError: Error, LocalizedError, Sendable {
    case missingAuthCode
    case codeAlreadyUsed

    public var errorDescription: String? {
        switch self {
        case .missingAuthCode:
            return "Please start the authorization flow again."
        case .codeAlreadyUsed:
            return "Auth code already used, please start authorization flow again."
        }
    }
}

extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    static let pkceKey = "com.pingidentity.oidcWeb.PKCE"

    /// The key used to store the expected `state` value for callback validation.
    static let stateKey = "com.pingidentity.oidcWeb.state"
    
    /// The key used to store the callbackURLScheme value in the shared context.
    static let callbackURLSchemeKey = "com.pingidentity.oidcWeb.callbackURLScheme"

    /// The key used to store the full redirectUri value in the shared context.
    static let redirectUriKey = "com.pingidentity.oidcWeb.redirectUri"

    /// The key used to store the user in the shared context.
    static let userKey = "com.pingidentity.oidcWeb.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    static let oidcClientConfigKey = "com.pingidentity.oidcWeb.OidcClientConfig"
    
    /// The key used to indicate if the flow is running in a web environment.
    static let oidcIsWeb = "com.pingidentity.oidcWeb.isWeb"
    
    /// The key used to store additional parameters for the OIDC flow.
    static let oidcParameters = "com.pingidentity.oidcWeb.parameters"

    /// The key used to store per-transaction RFC 9396 authorization_details for the OIDC flow.
    static let oidcAuthorizationDetails = "com.pingidentity.oidcWeb.authorizationDetails"
}

