// 
//  GoogleHandlerUtils.swift
//  ExternalIdPGoogle
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import UIKit
import PingExternalIdP
import GoogleSignIn

/// Utility class for handling Google Sign-In operations.
@MainActor
class GoogleHandlerUtils {
    /// Authorizes the user with Google Sign-In and returns an IdpResult containing the ID token.
    /// - Parameter idpClient: The IdpClient containing the client ID and scopes.
    /// - Returns: An IdpResult containing the ID token and additional parameters.
    /// - Throws: An error if the authorization fails.
    static func authorize(idpClient: IdpClient) async throws -> IdpResult {
        GIDSignIn.sharedInstance.signOut()
        let topVC = try IdpValidationUtils.validateTopViewController()
        try IdpValidationUtils.validateClientId(idpClient.clientId, provider: "Google")
        
        let token = try await GoogleAuthenticationManager.performGoogleSignIn(presenting: topVC, idpClient: idpClient)
        return IdpResult(token: token, additionalParameters: nil)
    }
}

class GoogleAuthenticationManager {
    /// Performs the Google Sign-In flow and returns a Sendable ID token string.
    /// This entire function runs on the main thread to ensure UI and result safety.
    static func performGoogleSignIn(presenting window: UIViewController, idpClient: IdpClient) async throws -> String {
        
        let signInResult: GIDSignInResult
        
        do {
            // 1. Call the sign-in method, which is confined to the Main Actor.
            signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: window, hint: nil, additionalScopes: idpClient.scopes, nonce: idpClient.nonce)
            let user = try await signInResult.user.refreshTokensIfNeeded()
            guard let idToken = user.idToken?.tokenString else {
                throw IdpExceptions.illegalStateException(message: IdpErrorMessages.googleTokenMissing)
            }
            
            return idToken
        } catch {
            // Handle Google's specific errors
            throw IdpExceptions.illegalStateException(message: error.localizedDescription)
        }
    }
}
