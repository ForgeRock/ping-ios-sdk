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
import PingNetwork

extension OidcClientConfig {
    /// Populates a DaVinci authorization request (synchronous, non-PAR).
    /// Kept for backwards compatibility.
    internal func populateRequest(
        request: Request,
        pkce: Pkce
    ) -> Request {
        let request = request
        request.url = openId?.authorizationEndpoint ?? ""
        request.setParameter(name: OidcClient.Constants.response_mode, value: OidcClient.Constants.piflow)
        buildAuthorizeParams(pkce: pkce) { key, value in
            request.setParameter(name: key, value: value)
        }
        return request
    }
    
    /// Populates a DaVinci authorization request handling both standard and PAR (RFC 9126) flows.
    internal func populateRequest(
        request: Request,
        pkce: Pkce
    ) async throws -> Request {
        // Delegate to the shared async populateRequest with pi.flow response mode
        return try await populateRequest(request: request, pkce: pkce, responseMode: OidcClient.Constants.piflow)
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
