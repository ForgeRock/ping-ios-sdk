//
//  FacebookRequestHandler.swift
//  ExternalIdPFacebook
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingNetwork
internal import FBSDKLoginKit
internal import FBSDKCoreKit
import UIKit
import PingExternalIdP

/// The tracking mode for Facebook login.
///
/// Use `.enabled` (the default) for standard Facebook login that collects
/// tracking data. Use `.limited` to opt in to Facebook Limited Login, which
/// restricts data collection and uses an authentication token (`id_token`)
/// instead of an access token.
public enum FacebookTrackingMode: Sendable {
    /// Standard Facebook login with tracking enabled (default).
    case enabled
    /// Facebook Limited Login with restricted data collection.
    case limited
}

/// A handler class for managing Facebook Identity Provider (IdP) authorization.
@MainActor
@objc public class FacebookRequestHandler: NSObject, IdpRequestHandler {
    /// `LoginManager` instance for Facebook SDK
    private var manager: LoginManager
    /// The HTTP client to use for requests.
    private let httpClient: URLSessionHttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    /// The tracking mode that controls whether standard or limited login is used.
    private let trackingMode: FacebookTrackingMode
    /// LoginConfiguration computed var
    private var configuration: LoginConfiguration? {
        var scopes: Set<FBSDKCoreKit.Permission> = []
        for scope in idpClient?.scopes ?? [] {
            let permission = FBSDKCoreKit.Permission(stringLiteral: scope)
            scopes.insert(permission)
        }
        let tracking: LoginTracking = (trackingMode == .limited) ? .limited : .enabled
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
    /// - Parameters:
    ///   - httpClient: The `URLSessionHttpClient` to use for requests.
    ///   - trackingMode: The tracking mode to use for Facebook login. Defaults to `.enabled`.
    init(httpClient: URLSessionHttpClient, trackingMode: FacebookTrackingMode) {
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
        self.trackingMode = trackingMode
    }

    /// Initializes a new instance of `FacebookRequestHandler` with standard tracking enabled.
    /// - Parameter httpClient: The `URLSessionHttpClient` to use for requests.
    @objc(initWithHttpClient:)
    convenience init(httpClient: URLSessionHttpClient) {
        self.init(httpClient: httpClient, trackingMode: .enabled)
    }

    /// Initializes a new instance of `FacebookRequestHandler` via an ObjC bridge.
    ///
    /// This initializer is called from `IdpCollector` via ObjC message-send when
    /// `facebookLimitedLoginEnabled` is set on the collector. The `isLimitedLogin`
    /// flag maps `true` to `.limited` and `false` to `.enabled`.
    ///
    /// - Parameters:
    ///   - httpClient: The `URLSessionHttpClient` to use for requests.
    ///   - isLimitedLogin: Pass `true` to use Facebook Limited Login (`.limited` tracking);
    ///     pass `false` for standard login (`.enabled` tracking).
    @objc(initWithHttpClient:isLimitedLogin:)
    convenience init(httpClient: URLSessionHttpClient, isLimitedLogin: Bool) {
        self.init(httpClient: httpClient, trackingMode: isLimitedLogin ? .limited : .enabled)
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
        let result = try await FacebookHandlerUtils.authorize(idpClient: idpClient, configuration: self.configuration, manager: self.manager)
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.invalidConfiguration)
        }
        let request = httpClient.request()
        request.url = continueUrl
        request.setHeader(name: NetworkConstants.headerAccept, value: NetworkConstants.contentTypeJSON)
        let tokenKey = trackingMode == .limited ? NetworkConstants.idToken : NetworkConstants.accessToken
        request.post(json: [tokenKey: result.token])
        return request
    }
}
