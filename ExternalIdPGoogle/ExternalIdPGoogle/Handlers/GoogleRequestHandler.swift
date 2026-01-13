//
//  GoogleRequestHandler.swift
//  ExternalIdP
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingNetwork
import UIKit
import PingExternalIdP
import GoogleSignIn

/// A handler class for managing Google Identity Provider (IdP) authorization.
@MainActor
@objc public class GoogleRequestHandler: NSObject, IdpRequestHandler {
    /// The HTTP client to use for requests.
    private let httpClient: URLSessionHttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    private(set) var isNativeAvailable: Bool = false
    
    /// Initializes a new instance of `GoogleRequestHandler`.
    /// - Parameter httpClient: The HTTP client to use for requests.
    @objc(initWithHttpClient:)
    init(httpClient: URLSessionHttpClient) {
        self.httpClient = httpClient
    }
    
    @discardableResult
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey:Any]?) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: An `HttpRequest` object containing the result of the authorization.
    public func authorize(url: URL?) async throws -> HttpRequest {
        do {
            self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
        } catch {
            throw IdpExceptions.unsupportedIdpException(message: "\(IdpErrorMessages.idpFetchFailed) \(error.localizedDescription)")
        }
        guard let idpClient = self.idpClient else {
            throw IdpExceptions.unsupportedIdpException(message: IdpErrorMessages.invalidConfiguration)
        }
        let result = try await GoogleHandlerUtils.authorize(idpClient: idpClient)
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.invalidConfiguration)
        }
        
        let request = httpClient.request()
        request.url = continueUrl
        request.setHeader(name: NetworkConstants.headerAccept, value: NetworkConstants.contentTypeJSON)
        request.post(json: [NetworkConstants.idToken: result.token])
        return request
    }
}
