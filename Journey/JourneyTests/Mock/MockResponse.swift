//
//  MockResponse.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

struct MockResponse {
    static let headers = ["Content-Type": "application/json"]
    
    // Return the OpenID configuration response as Data
    static var openIdConfigurationResponse: Data {
        return """
        {
            "authorization_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/authorize",
            "token_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/token",
            "userinfo_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/userinfo",
            "end_session_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/connect/endSession",
            "revocation_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/revoke"
        }
        """.data(using: .utf8)!
    }
    
    // TODO: Add AIC specific mock responses here
}
