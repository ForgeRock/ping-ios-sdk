//
//  BrowserHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingBrowser
import PingOrchestrate

/// A handler class for managing browser-based Identity Provider (IdP) authorization.
@MainActor
public class BrowserHandler: IdpRequestHandler {
    public var continueNode: ContinueNode
    public var callbackURLScheme: String
    
    /// Initializes a new instance of `BrowserHandler`.
    /// - Parameters:
    ///     - continueNode: The `ContinueNode` to use.
    ///     - tokenType: The token type to use.
    ///     - callbackURLScheme: The callback URL scheme to use.
    public init(continueNode: ContinueNode, callbackURLScheme: String) {
        self.callbackURLScheme = callbackURLScheme
        self.continueNode = continueNode
    }
    
    /// Authorizes a user by making a request to the given URL.
    ///  This function takes a JSON object and extracts the "form" field. It then iterates over the "fields" array in the "components" object,
    ///  parsing each field into a collector and adding it to a list.
    ///  - Parameter url: The URL to which the authorization request is made.
    ///  - Returns:  A [Request] object that can be used to continue the DaVinci flow.
    public func authorize(url: URL?) async throws -> Request {
        guard let continueUrl = url else {
            throw IdpExceptions.illegalArgumentException(message: "continueUrl not found")
        }
        
        do {
            let result = try await BrowserLauncher.currentBrowser.launch(url: continueUrl, browserType: .ephemeralAuthSession, callbackURLScheme: callbackURLScheme)
            
            guard let components = URLComponents(url: result, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                throw IdpExceptions.illegalStateException(message: "Could not read response URL")
            }
                
            guard let continueToken = queryItems.first(where: { $0.name == "continueToken" })?.value else {
                throw IdpExceptions.illegalStateException(message: "Could not read continueToken")
            }
            
            guard let links = continueNode.input[Request.Constants._links] as? [String: Any],
                  let _continue = links[Request.Constants._continue] as? [String: Any],
                  let continueURL = _continue[Request.Constants.href] as? String else {
                throw IdpExceptions.illegalStateException(message: "Could not read continue URL")
            }
            
            let request = Request(urlString: continueURL)
            request.header(name: Request.Constants.authorization, value: "Bearer \(continueToken)")
            request.body(body: [String: Any]())
            return request
        } catch let error {
            throw error
        }
    }
}
