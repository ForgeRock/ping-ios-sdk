//
//  OpenIdConfiguration.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct representing the OpenID Connect configuration.
public struct OpenIdConfiguration: Codable, Sendable {
    /// The URL of the authorization endpoint.
    public var authorizationEndpoint: String
    /// The URL of the token endpoint.
    public var tokenEndpoint: String
    /// The URL of the userinfo endpoint.
    public var userinfoEndpoint: String
    /// The URL of the end session endpoint.
    public var endSessionEndpoint: String
    /// The URL of the revocation endpoint.
    public var revocationEndpoint: String
    /// The URL of the end session endpoint.
    public var pingEndsessionEndpoint: String?
    /// The URL of the pushed authorization request endpoint (PAR, RFC 9126).
    public var pushedAuthorizationRequestEndpoint: String?
    /// The URL of the device authorization endpoint (RFC 8628).
    public var deviceAuthorizationEndpoint: String?

    /// Initializes a new `OpenIdConfiguration` instance.
    /// - Parameters:
    ///   - authorizationEndpoint: The URL of the authorization endpoint.
    ///   - tokenEndpoint: The URL of the token endpoint.
    ///   - userinfoEndpoint: The URL of the userinfo endpoint.
    ///   - endSessionEndpoint: The URL of the end session endpoint.
    ///   - revocationEndpoint: The URL of the revocation endpoint.
    ///   - pingEndsessionEndpoint: The URL of the Ping end IDP session endpoint.
    ///   - pushedAuthorizationRequestEndpoint: The URL of the PAR endpoint.
    ///   - deviceAuthorizationEndpoint: The URL of the device authorization endpoint (RFC 8628).
    public init(
        authorizationEndpoint: String,
        tokenEndpoint: String,
        userinfoEndpoint: String,
        endSessionEndpoint: String,
        revocationEndpoint: String,
        pingEndsessionEndpoint: String? = nil,
        pushedAuthorizationRequestEndpoint: String? = nil,
        deviceAuthorizationEndpoint: String? = nil
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.userinfoEndpoint = userinfoEndpoint
        self.endSessionEndpoint = endSessionEndpoint
        self.revocationEndpoint = revocationEndpoint
        self.pingEndsessionEndpoint = pingEndsessionEndpoint
        self.pushedAuthorizationRequestEndpoint = pushedAuthorizationRequestEndpoint
        self.deviceAuthorizationEndpoint = deviceAuthorizationEndpoint
    }

    // Define CodingKeys enum to map serialized names to property names
    private enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case pingEndsessionEndpoint = "ping_end_idp_session_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case deviceAuthorizationEndpoint = "device_authorization_endpoint"
    }
}
