//
//  GoogleRequestHandler.swift
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
@objc public class GoogleRequestHandler: NSObject, IdpRequestHandler {
    /// The HTTP client to use for requests.
    private let httpClient: HttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    private(set) var isNativeAvailable: Bool = false
    
    /// Initializes a new instance of `GoogleRequestHandler`.
    /// - Parameter httpClient: The HTTP client to use for requests.
    @objc(initWithHttpClient:)
    init(httpClient: HttpClient) {
        self.httpClient = httpClient
    }
    
    @discardableResult
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey:Any]?) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: A `Request` object containing the result of the authorization.
    public func authorize(url: URL?) async throws -> Request {
        do {
            self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
        } catch {
            throw IdpExceptions.unsupportedIdpException(message: "\(IdpErrorMessages.idpFetchFailed) \(error.localizedDescription)")
        }
        guard let idpClient = self.idpClient else {
            throw IdpExceptions.unsupportedIdpException(message: IdpErrorMessages.invalidConfiguration)
        }
        let result = try await self.authorize(idpClient: idpClient)
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.invalidConfiguration)
        }
        let request = Request(urlString: continueUrl)
        request.header(name: Request.Constants.accept, value: Request.ContentType.json.rawValue)
        request.body(body: [Request.Constants.idToken: result.token])
        return request
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    private func authorize(idpClient: IdpClient) async throws -> IdpResult {
        GIDSignIn.sharedInstance.signOut()
        let topVC = try IdpValidationUtils.validateTopViewController()
        try IdpValidationUtils.validateClientId(idpClient.clientId, provider: "Google")
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                GIDSignIn.sharedInstance.signIn(withPresenting: topVC, hint: nil, additionalScopes: idpClient.scopes, nonce: idpClient.nonce) { result, error in
                    if let error = error {
                        continuation.resume(throwing: IdpExceptions.illegalStateException(message: error.localizedDescription))
                        return
                    }
                    guard let result = result else {
                        continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.googleResultMissing))
                        return
                    }
                    result.user.refreshTokensIfNeeded { user, error in
                        guard error == nil else {
                            continuation.resume(throwing: error!)
                            return
                        }
                        guard let _ = user else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.googleUserMissing))
                            return
                        }
                        guard let token = result.user.idToken?.tokenString else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.googleTokenMissing))
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
