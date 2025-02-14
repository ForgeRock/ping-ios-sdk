//
//  IdpRequestHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Interface representing an Identity Provider (IdP) handler.
public protocol IdpRequestHandler {
    /// The type of token to use for the IdP.
    var tokenType: String { get set }
    
    /// Authorizes the user with the IdP.
    /// - Parameter url: The URL to use for authorization.
    /// - Returns: A `Request` object containing the result of the authorization
    func authorize(url: URL?) async throws -> Request
}

