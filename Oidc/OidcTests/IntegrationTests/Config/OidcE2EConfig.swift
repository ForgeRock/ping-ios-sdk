//
//  OidcE2EConfig.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

struct OidcE2EConfig {
    let clientId: String
    let discoveryEndpoint: String
    let scopes: [String]
    let redirectUri: String
    let acrValues: String
    /// Optional: e.g. "pi.flow" for PingOne DaVinci flows; empty for AIC.
    let responseMode: String

    // NOTE: intentionally scoped to OidcTests. If another test target needs this,
    // pass `bundle` as a parameter or copy and adjust the Bundle reference.
    init(_ fileName: String) throws {
        guard let path = Bundle(for: OidcWebClientE2ETests.self)
                .path(forResource: fileName, ofType: "json")
        else {
            throw OidcE2EConfigError.fileNotFound(fileName)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientId = json["clientId"] as? String,
              let discoveryEndpoint = json["discoveryEndpoint"] as? String,
              let scopesString = json["scopes"] as? String,
              let redirectUri = json["redirectUri"] as? String
        else {
            throw OidcE2EConfigError.invalidConfig(fileName)
        }
        self.clientId = clientId
        self.discoveryEndpoint = discoveryEndpoint
        self.scopes = scopesString.split(separator: " ").map(String.init)
        self.redirectUri = redirectUri
        self.acrValues = json["acrValues"] as? String ?? ""
        self.responseMode = json["responseMode"] as? String ?? ""
    }
}

enum OidcE2EConfigError: Error {
    case fileNotFound(String)
    case invalidConfig(String)
}
