//
//  GoogleRequestHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import GoogleSignIn
import UIKit

/// A handler class for managing Google Identity Provider (IdP) authorization.
class GoogleRequestHandler: IdpRequestHandler {
    /// Credentials type for Google credentials
    var tokenType: String = "id_token"
    
    /// The HTTP client to use for requests.
    private let httpClient: HttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    /// Initializes a new instance of `AppleRequestHandler`.
    /// - Parameter httpClient: The HTTP client to use for requests.
    init(httpClient: HttpClient) {
        self.httpClient = httpClient
    }
    
    // Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: A `Request` object containing the result of the authorization.
    func authorize(url: URL?) async throws -> Request {
        do {
            do {
                self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
            } catch {
                throw IdpExceptions.unsupportedIdpException(message: "IdpClient fetch failed")
            }
            guard let idpClient = self.idpClient else {
                throw IdpExceptions.unsupportedIdpException(message: "IdpClient is nil")
            }
            let result = try await self.authorize(idpClient: idpClient)
            let request = Request(urlString: idpClient.continueUrl ?? "")
            request.header(name: Request.Constants.accept, value: Request.ContentType.json.rawValue)
            request.body(body: [Request.Constants.idToken: result.token])
            return request
        } catch {
            throw error
        }
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    @MainActor
    private func authorize(idpClient: IdpClient) async throws -> IdpResult {
        GIDSignIn.sharedInstance.signOut()
        guard let _ = idpClient.clientId else {
            throw IdpExceptions.illegalArgumentException(message: "Client ID is required")
        }
        guard let topVC = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?.rootViewController else {
            throw IdpExceptions.illegalStateException(message: "Top view controller is required")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: topVC, hint: nil, additionalScopes: idpClient.scopes, nonce: idpClient.nonce) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                if let result = result {
                    result.user.refreshTokensIfNeeded { user, error in
                        guard error == nil else {
                            continuation.resume(throwing: error!)
                            return
                        }
                        guard let _ = user else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: "User returned nil"))
                            return
                        }
                        guard let token = result.user.idToken?.tokenString else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: "ID Token is required and not found on result"))
                            return
                        }
                        let idpResult = IdpResult(token: token, additionalParameters: nil)
                        continuation.resume(returning: idpResult)
                    }
                }
            }
        }
    }
}
