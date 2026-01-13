//
//  Request.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate

extension OidcClientConfig {
    internal func populateRequest(
        request: Request,
        pkce: Pkce
    ) -> Request {
        let request = request
        request.url = openId?.authorizationEndpoint ?? ""
        request.setParameter(name: OidcClient.Constants.response_mode, value: "pi.flow")
        request.setParameter(name: OidcClient.Constants.client_id, value: clientId)
        request.setParameter(name: OidcClient.Constants.response_type, value: OidcClient.Constants.code)
        request.setParameter(name: OidcClient.Constants.scope, value: scopes.joined(separator: " "))
        request.setParameter(name: OidcClient.Constants.redirect_uri, value: redirectUri)
        request.setParameter(name: OidcClient.Constants.code_challenge, value: pkce.codeChallenge)
        request.setParameter(name: OidcClient.Constants.code_challenge_method, value: pkce.codeChallengeMethod)
        
        if let acr = acrValues {
            request.setParameter(name: OidcClient.Constants.acr_values, value: acr)
        }
        
        if let display = display {
            request.setParameter(name: OidcClient.Constants.display, value: display)
        }
        
        for (key, value) in additionalParameters {
            request.setParameter(name: key, value: value)
        }
        
        if let loginHint = loginHint {
            request.setParameter(name: OidcClient.Constants.login_hint, value: loginHint)
        }
        
        if let nonce = nonce {
            request.setParameter(name: OidcClient.Constants.nonce, value: nonce)
        }
        
        if let prompt = prompt {
            request.setParameter(name: OidcClient.Constants.prompt, value: prompt)
        }
        
        if let uiLocales = uiLocales {
            request.setParameter(name: OidcClient.Constants.ui_locales, value: uiLocales)
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
}
