//
//  AppleHandler.swift
//  ExternalIdPApple
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import AuthenticationServices
import PingExternalIdP

///IdpHandler for Apple
@MainActor
@objc final class AppleHandler: NSObject, @preconcurrency IdpHandler, Sendable {
    
    /// Token type for the IdpHandler.
    var tokenType: String = "id_token"
    
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    public func authorize(idpClient: IdpClient) async throws -> IdpResult {
        let helper = SignInWithAppleHelper(idpClient: idpClient)
        
        // Sign in to Apple account
        for try await appleResponse in helper.startSignInWithAppleFlow() {
            guard let token = appleResponse.appleSignInResponse.id_token else {
                throw IdpExceptions.illegalStateException(message: "Apple Sign In failed. No token received.")
            }
            
            guard let IDToken1tokenJSON = try? JSONEncoder().encode(appleResponse.appleSignInResponse), let IDToken1token = String(data: IDToken1tokenJSON, encoding: .utf8) else {
                throw IdpExceptions.illegalStateException(message: "Encoding Apple Sign In response failed")
            }
            
            return IdpResult(token: token, additionalParameters: [AppleHandler.acceptsJSON: IDToken1token])
        }
        throw IdpExceptions.illegalStateException(message: "Apple Sign In failed")
    }
}

extension AppleHandler {
    public static let acceptsJSON = "acceptsJSON"
}
