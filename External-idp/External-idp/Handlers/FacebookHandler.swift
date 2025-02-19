//
//  FacebookHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation
import PingOrchestrate

/// A handler class for managing Facebook authorization.
class FacebookHandler: IdpHandler {
    
    //  MARK: - Properties
    
    /// Credentials type for Facebook credentials
    var tokenType: String = "access_token"
    
    /// Authorizes the user with the IDP.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    func authorize(idpClient: IdpClient) async throws -> IdpResult {
        throw IdpExceptions.unsupportedIdpException(message: "Facebook is not implemented yet")
    }
}
