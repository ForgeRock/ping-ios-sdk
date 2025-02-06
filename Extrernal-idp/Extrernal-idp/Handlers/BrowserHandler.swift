//
//  BrowserHandler.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingBrowser
import PingOrchestrate

public class BrowserHandler: IdpHandler {
    public var tokenType: String
    public var continueNode: ContinueNode
    public var callbackURLScheme: String
    
    public init(continueNode: ContinueNode, tokenType: String, callbackURLScheme: String) {
        self.tokenType = tokenType
        self.callbackURLScheme = callbackURLScheme
        self.continueNode = continueNode
    }
    
    public func authorize(url: URL?) async throws -> Request {
        guard let continueUrl = url else {
            throw IdpExceptions.illegalArgumentException(message: "continueUrl not found")
        }
        
        do {
            let result = try await BrowserLauncher.currentBrowser?.launch(url: continueUrl, callbackURLScheme: callbackURLScheme)
            guard let url = result,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
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
        } catch {
            throw IdpExceptions.illegalStateException(message: "BrowserLauncher failed")
        }
    }
    
    
}
