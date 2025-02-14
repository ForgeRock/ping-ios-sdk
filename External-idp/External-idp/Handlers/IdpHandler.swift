//
//  IdpHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Logger protocol that provides methods for logging different levels of information.
public protocol IdpHandler {
    var tokenType: String { get set }
    
    /// Authorizes the user with the IDP.
    /// - Parameter idpClient: The IDP client to authorize.
    /// - Returns: A `Result` object containing either the `IdpResult` or an `IdpError`.
    func authorize(idpClient: IdpClient) async throws -> IdpResult
}
