//
//  FacebookHandler.swift
//  Extrernal-idp
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
    
    /// `LoginManager` instance for Facebook SDK
//    var loginManager: LoginManager = LoginManager()
    
    // Authorization call
    func authorize(url: URL?) async throws -> Request {
        throw IdpExceptions.unsupportedIdpException(message: "Facebook is not implemented yet")
    }
    
    
}
