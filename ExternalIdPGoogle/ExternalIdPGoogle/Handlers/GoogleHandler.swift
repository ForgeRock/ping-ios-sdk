//
//  GoogleHandler.swift
//  ExternalIdP
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

/// A handler class for managing Google Identity Provider (IdP) authorization.
@MainActor
@objc public final class GoogleHandler: NSObject, @preconcurrency IdpHandler, Sendable {
    /// The type of token to be used for authorization.
    public var tokenType: String = "id_token"
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    private(set) var isNativeAvailable: Bool = false
    
    @discardableResult
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey: Any]?) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    public func authorize(idpClient: IdpClient) async throws -> IdpResult {
        GIDSignIn.sharedInstance.signOut()
        let topVC = try IdpValidationUtils.validateTopViewController()
        try IdpValidationUtils.validateClientId(idpClient.clientId, provider: "Google")
        
        return try await Task { @MainActor in
            let token = try await GoogleAuthenticationManager.performGoogleSignIn(presenting: topVC, idpClient: idpClient)
            return IdpResult(token: token, additionalParameters: nil)
        }.value
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
