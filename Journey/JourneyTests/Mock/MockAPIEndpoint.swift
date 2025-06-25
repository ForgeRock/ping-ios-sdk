//
//  MockAPIEndpoint.swift
//  JourneyTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

enum MockAPIEndpoint {
    static let baseURL = "https://openam-bafaloukas.forgeblocks.com/am"
    
    case authorization
    case token
    case userinfo
    case endSession
    case revocation
    case discovery
    
    var url: URL {
        switch self {
        case .authorization:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/alpha/authorize")!
        case .token:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/alpha/access_token")!
        case .userinfo:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/alpha/userinfo")!
        case .endSession:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/alpha/connect/endSession")!
        case .revocation:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/alpha/revoke")!
        case .discovery:
            return URL(string: "\(MockAPIEndpoint.baseURL)/oauth2/realms/alpha/.well-known/openid-configuration")!
        }
    }
}
