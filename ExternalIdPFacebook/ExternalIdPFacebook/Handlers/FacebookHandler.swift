//
//  FacebookHandler.swift
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
@objc public class FacebookHandler: NSObject, @preconcurrency IdpHandler, Sendable {
    
    /// The type of token this handler supports.
    public var tokenType: String = "access_token"
    
    /// `LoginManager` instance for Facebook SDK
    private var manager: LoginManager
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
    @objc(init)
    override init() {
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
    }
    
    /// Handles the opening of a URL in the application.
    /// - Parameters:
    ///  - app: The `UIApplication` instance.
    ///  - url: The URL to be opened.
    ///  - options: Additional options for opening the URL.
    /// - Returns: A boolean indicating whether the URL was handled successfully.
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
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameters:
    ///  - idpClient: The `IdpClient` to use for authorization.
    /// - Throws: An error if the authorization fails.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    public func authorize(idpClient: IdpClient) async throws -> IdpResult {
        let topVC = try IdpValidationUtils.validateTopViewController()
        
        guard let validConfiguration = configuration else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.facebookConfigurationInvalid)
        }
        
        return try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<IdpResult, Error>) in
            guard let self = self else {
                continuation.resume(throwing: IdpExceptions.illegalStateException(message: "Self was deallocated"))
                return
            }
            
            Task { @MainActor [weak self] in
                self?.manager.logIn(viewController: topVC, configuration: validConfiguration) { result in
                    switch result {
                    case .cancelled:
                        continuation.resume(throwing: IdpExceptions.idpCanceledException(message: IdpErrorMessages.userCancelled))
                    case .failed(let error):
                        continuation.resume(throwing: IdpExceptions.illegalStateException(message: error.localizedDescription))
                    case .success(_, _, let token):
                        guard let accessToken = token?.tokenString else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.facebookTokenMissing))
                            return
                        }
                        continuation.resume(returning: IdpResult(token: accessToken, additionalParameters: nil))
                    }
                }
            }
        }
    }
}
