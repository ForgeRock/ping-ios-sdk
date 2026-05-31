//
//  AppleRequestHandler.swift
//  ExternalIdPApple
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingNetwork
import AuthenticationServices
import PingExternalIdP

#if canImport(UIKit)
///IdpHandler for Apple
@MainActor
@objc class AppleRequestHandler: NSObject, IdpRequestHandler {
    /// The HTTP client to use for requests.
    private let httpClient: URLSessionHttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    /// Initializes a new instance of `AppleRequestHandler`.
    /// - Parameter httpClient: The HTTP client to use for requests.
    @objc(initWithHttpClient:)
    init(httpClient: URLSessionHttpClient) {
        self.httpClient = httpClient
    }
    
    /// Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: An `HttpRequest` object containing the result of the authorization.
    func authorize(url: URL?) async throws -> HttpRequest {
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
        let request = httpClient.request()
        request.url = continueUrl
        request.setHeader(name: NetworkConstants.headerAccept, value: NetworkConstants.contentTypeJSON)
        request.post(json: [NetworkConstants.idToken: result.token])
        return request
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    private func authorize(idpClient: IdpClient) async throws -> IdpResult {
        let helper = SignInWithAppleHelper(idpClient: idpClient)
        
        // Sign in to Apple account
        for try await appleResponse in helper.startSignInWithAppleFlow() {
            guard let token = appleResponse.appleSignInResponse.id_token else {
                throw IdpExceptions.illegalStateException(message: IdpErrorMessages.appleTokenMissing)
            }
            
            let nonce = appleResponse.nonce ?? ""
            let displayName = appleResponse.displayName ?? ""
            let firstName = appleResponse.appleSignInResponse.user.name?.firstName ?? ""
            let lastName = appleResponse.appleSignInResponse.user.name?.lastName ?? ""
            let email = appleResponse.appleSignInResponse.user.email
            
            return IdpResult(token: token, additionalParameters: ["name": displayName, "firstName": firstName, "lastName": lastName, "nonce": nonce, "email": email])
        }
        throw IdpExceptions.illegalStateException(message: IdpErrorMessages.appleSignInFailed)
    }
}
#endif
