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
    public var tokenType: String = IdpConstants.id_token
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    private(set) var isNativeAvailable: Bool = false
    
    @discardableResult
    public static func handleOpenURL(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey: Any]?) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameters:
    ///     - idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    /// - Throws: An error if the authorization fails.
    public func authorize(idpClient: IdpClient) async throws -> IdpResult {
        return try await GoogleHandlerUtils.authorize(idpClient: idpClient)
    }
}


