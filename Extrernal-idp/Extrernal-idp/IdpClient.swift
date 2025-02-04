//
//  IdpClient.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

public class IdpClient {
    public let clientId: String?
    public let redirectUri: String?
    public let scopes: [String]?
    public let nonce: String?
    public let continueUrl: String?
    
    public init(clientId: String? = nil, redirectUri: String? = nil, scopes: [String]? = nil, nonce: String? = nil, continueUrl: String? = nil) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scopes = scopes
        self.nonce = nonce
        self.continueUrl = continueUrl
    }
}
