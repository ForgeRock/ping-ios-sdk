//
//  FacebookHandler.swift
//  ExternalIdPFacebook
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(FBSDKLoginKit)
import Foundation
internal import FBSDKLoginKit
internal import FBSDKCoreKit
import UIKit
import PingExternalIdP

/// A handler class for managing Facebook Identity Provider (IdP) authorization.
@MainActor
@objc public class FacebookHandler: NSObject, @preconcurrency IdpHandler, FacebookLimitedLoginConfigurable, Sendable {
    
    /// The type of token this handler supports. Updated automatically when `facebookLimitedLoginEnabled` changes.
    public var tokenType: String = IdpConstants.access_token

    /// When `true`, uses Facebook Limited Login (OIDC ID token) with `tracking: .limited`;
    /// otherwise classic OAuth2 (access token) with `tracking: .enabled`.
    /// KVC-settable for callers that cannot import this module directly (e.g. `IdpCallback`
    /// in `ExternalIdP`, which reaches this handler via `NSClassFromString`).
    @objc public var facebookLimitedLoginEnabled: Bool = false {
        didSet {
            tokenType = facebookLimitedLoginEnabled ? IdpConstants.id_token : IdpConstants.access_token
        }
    }

    /// `LoginManager` instance for Facebook SDK
    private var manager: LoginManager
    /// The IdpClient to use for requests. Populated by `authorize(idpClient:)` so `configuration`
    /// can read `scopes` and `nonce` off it.
    private var idpClient: IdpClient?
    /// LoginConfiguration computed var
    private var configuration: LoginConfiguration? {
        var scopes: Set<FBSDKCoreKit.Permission> = []
        for scope in idpClient?.scopes ?? [] {
            let permission = FBSDKCoreKit.Permission(stringLiteral: scope)
            scopes.insert(permission)
        }
        let tracking: LoginTracking = facebookLimitedLoginEnabled ? .limited : .enabled
        if let nonce = idpClient?.nonce, !nonce.isEmpty {
            return LoginConfiguration(
                permissions: scopes,
                tracking: tracking,
                nonce: nonce
            )
        }
        else {
            return LoginConfiguration(
                permissions: scopes,
                tracking: tracking
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
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey: Any]?) -> Bool {
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
        self.idpClient = idpClient
        return try await FacebookHandlerUtils.authorize(idpClient: idpClient, configuration: self.configuration, manager: self.manager, isLimited: facebookLimitedLoginEnabled)
    }
}
#endif
