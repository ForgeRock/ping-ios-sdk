//
//  OpenIdConfiguration.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct representing the OpenID Connect configuration.
public struct OpenIdConfiguration: Codable {
    /// The URL of the authorization endpoint.
    public let authorizationEndpoint: String
    /// The URL of the token endpoint.
    public let tokenEndpoint: String
    /// The URL of the userinfo endpoint.
    public let userinfoEndpoint: String
    /// The URL of the end session endpoint.
    public let endSessionEndpoint: String
    /// The URL of the revocation endpoint .
    public let revocationEndpoint: String
    
    // Define CodingKeys enum to map serialized names to property names
    private enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
        case revocationEndpoint = "revocation_endpoint"
    }
}
