//
//  FacebookRequestHandler.swift
//  ExternalIdPFacebook
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import FBSDKLoginKit
import FBSDKCoreKit
import UIKit
import PingExternalIdP

/// A handler class for managing Facebook Identity Provider (IdP) authorization.
@MainActor
@objc public class FacebookRequestHandler: NSObject, IdpRequestHandler {
    /// `LoginManager` instance for Facebook SDK
    private var manager: LoginManager
    /// The HTTP client to use for requests.
    private let httpClient: HttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    /// LoginConfiguration computed var
    private var configuration: LoginConfiguration? {
        var scopes: Set<FBSDKCoreKit.Permission> = []
        for scope in idpClient?.scopes ?? [] {
            let permission = FBSDKCoreKit.Permission(stringLiteral: scope)
            scopes.insert(permission)
        }
        if let nonce = idpClient?.nonce, !nonce.isEmpty {
            return LoginConfiguration(
                permissions: scopes,
                tracking: .enabled,
                nonce: nonce
            )
        }
        else {
            return LoginConfiguration(
                permissions: scopes,
                tracking: .enabled
            )
        }
    }
    
    /// Initializes a new instance of `FacebookRequestHandler`.
    /// - Parameter httpClient: The `HttpClient` to use for requests
    @objc(initWithHttpClient:)
    init(httpClient: HttpClient) {
        DispatchQueue.main.async {
            /// Initialize Facebook SDK
            Settings.shared.isAdvertiserIDCollectionEnabled = true
            Settings.shared.isAutoLogAppEventsEnabled = true
            
            ApplicationDelegate.shared.initializeSDK()
        }
        //  Initialize Facebook LoginManager instance
        self.manager = LoginManager()
        //  Perform logout to clear previously authenticated session
        self.manager.logOut()
        
        self.httpClient = httpClient
    }
    
    @discardableResult
      public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey:Any]?) -> Bool {
          ApplicationDelegate.shared.application(
                      app,
                      open: url,
                      sourceApplication: options?[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
                      annotation: options?[UIApplication.OpenURLOptionsKey.annotation]
                  )
          return true
      }
    
    // Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: A `Request` object containing the result of the authorization.
    public func authorize(url: URL?) async throws -> Request {
        do {
            self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
        } catch {
            throw IdpExceptions.unsupportedIdpException(message: "IdpClient fetch failed: \(error.localizedDescription)")
        }
        guard let idpClient = self.idpClient else {
            throw IdpExceptions.unsupportedIdpException(message: "IdpClient is nil")
        }
        let result = try await self.authorize(idpClient: idpClient)
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: "continueUrl is missing or empty")
        }
        let request = Request(urlString: continueUrl)
        request.header(name: Request.Constants.accept, value: Request.ContentType.json.rawValue)
        request.body(body: [Request.Constants.accessToken: result.token])
        return request
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    private func authorize(idpClient: IdpClient) async throws -> IdpResult {
        guard let topVC = IdpClient.getTopViewController() else {
            throw IdpExceptions.illegalStateException(message: "Top view controller is required")
        }
        
        guard let validConfiguration = configuration else {
            throw IdpExceptions.illegalStateException(message: "Invalid configuration")
        }
        
        return try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<IdpResult, Error>) in
            guard let self = self else {
                continuation.resume(throwing: IdpExceptions.illegalStateException(message: "Self was deallocated"))
                return
            }
            
            Task { @MainActor in
                self.manager.logIn(viewController: topVC, configuration: validConfiguration) { result in
                    switch result {
                    case .cancelled:
                        continuation.resume(throwing: IdpExceptions.idpCanceledException(message: "User cancelled login"))
                    case .failed(let error):
                        continuation.resume(throwing: error)
                    case .success(_, _, let token):
                        guard let accessToken = token?.tokenString else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: "Access Token is required and not found on result"))
                            return
                        }
                        continuation.resume(returning: IdpResult(token: accessToken, additionalParameters: nil))
                    }
                }
            }
        }
    }
}
