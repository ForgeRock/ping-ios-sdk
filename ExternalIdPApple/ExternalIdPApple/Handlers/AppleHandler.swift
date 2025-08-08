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
@objc public final class AppleHandler: NSObject, @preconcurrency IdpHandler, Sendable {
    
    /// Token type for the IdpHandler.
    public var tokenType: String = "id_token"
    
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameters:
    ///     - idpClient: The `IdpClient` instance used to initiate the authorization flow.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    /// - Throws: An error if the authorization fails or if the token is missing.
    public func authorize(idpClient: IdpClient) async throws -> IdpResult {
        let helper = SignInWithAppleHelper(idpClient: idpClient)
        
        // Sign in to Apple account
        for try await appleResponse in helper.startSignInWithAppleFlow() {
            guard let token = appleResponse.appleSignInResponse.id_token else {
                throw IdpExceptions.illegalStateException(message: IdpErrorMessages.appleTokenMissing)
            }
            
            guard let encodedResponseData = try? JSONEncoder().encode(appleResponse.appleSignInResponse),
                  let responseJsonString = String(data: encodedResponseData, encoding: .utf8) else {
                throw IdpExceptions.illegalStateException(message: IdpErrorMessages.appleEncodingFailed)
            }
            
            return IdpResult(token: token, additionalParameters: [AppleHandler.acceptsJSON: responseJsonString])
        }
        throw IdpExceptions.illegalStateException(message: IdpErrorMessages.appleSignInFailed)
    }
}

extension AppleHandler {
    public static let acceptsJSON = "acceptsJSON"
}
