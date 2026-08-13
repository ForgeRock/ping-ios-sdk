//
//  FacebookRequestHandler.swift
//  ExternalIdPFacebook
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(FBSDKLoginKit)
import Foundation
import PingNetwork
internal import FBSDKLoginKit
internal import FBSDKCoreKit
import UIKit
import PingExternalIdP

/// A handler class for managing Facebook Identity Provider (IdP) authorization for the DaVinci path.
@MainActor
@objc public class FacebookRequestHandler: NSObject, IdpRequestHandler, FacebookLimitedLoginConfigurable {
    /// `LoginManager` instance for Facebook SDK
    private var manager: LoginManager
    /// The HTTP client to use for requests.
    private let httpClient: URLSessionHttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?

    /// When `true`, uses Facebook Limited Login (OIDC ID token) with `tracking: .limited`;
    /// otherwise classic OAuth2 (access token) with `tracking: .enabled`. Defaults to `false`
    /// for backward compatibility. Adopting the `FacebookLimitedLoginConfigurable` protocol
    /// lets callers in modules that cannot import this one (e.g. `IdpCollector`) toggle it.
    @objc public var facebookLimitedLoginEnabled: Bool = false

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
        } else {
            return LoginConfiguration(
                permissions: scopes,
                tracking: tracking
            )
        }
    }

    /// Initializes a new instance of `FacebookRequestHandler`.
    /// - Parameter httpClient: The `URLSessionHttpClient` to use for requests
    @objc(initWithHttpClient:)
    init(httpClient: URLSessionHttpClient) {
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
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey: Any]?) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options?[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options?[UIApplication.OpenURLOptionsKey.annotation]
        )
        return true
    }

    /// Authorizes the user with Facebook and posts the result to the DaVinci `continueUrl`.
    ///
    /// With `facebookLimitedLoginEnabled == false` the request body is `{"accessToken": "<token>"}`.
    /// With `facebookLimitedLoginEnabled == true` the request body is `{"idToken": "<jwt>"}`.
    public func authorize(url: URL?) async throws -> HttpRequest {
        do {
            self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
        } catch {
            throw IdpExceptions.unsupportedIdpException(message: "\(IdpErrorMessages.idpFetchFailed) \(error.localizedDescription)")
        }
        guard let idpClient = self.idpClient else {
            throw IdpExceptions.unsupportedIdpException(message: IdpErrorMessages.invalidConfiguration)
        }
        let result = try await FacebookHandlerUtils.authorize(
            idpClient: idpClient,
            configuration: self.configuration,
            manager: self.manager,
            isLimited: facebookLimitedLoginEnabled
        )
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.invalidConfiguration)
        }
        let request = httpClient.request()
        request.url = continueUrl
        request.setHeader(name: NetworkConstants.headerAccept, value: NetworkConstants.contentTypeJSON)
        let payloadKey = facebookLimitedLoginEnabled ? NetworkConstants.idToken : NetworkConstants.accessToken
        request.post(json: [payloadKey: result.token])
        return request
    }
}
#endif
