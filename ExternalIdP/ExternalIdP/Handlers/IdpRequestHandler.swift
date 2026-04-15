//
//  IdpRequestHandler.swift
//  ExternalIdP
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingNetwork
import PingOrchestrate

/// Interface representing an Identity Provider (IdP) handler.
public protocol IdpRequestHandler: Sendable {
    /// Authorizes the user with the IdP.
    /// - Parameter url: The URL to use for authorization.
    /// - Returns: An `HttpRequest` object containing the result of the authorization
    func authorize(url: URL?) async throws -> HttpRequest
    
    /// Fetch the IdP client information from the server
    /// - Parameters:
    ///  - httpClient: The `HttpClientProtocol` to use for the request.
    ///  - url: The URL to use for the request.
    ///  - Returns: An `IdpClient` object containing the client information.
    func fetch(httpClient: any HttpClientProtocol, url: URL?) async throws -> IdpClient
}

extension IdpRequestHandler {
    /// Fetch the IdP client information from the server
    /// - Parameters:
    ///  - httpClient: The `HttpClientProtocol` to use for the request.
    ///  - url: The URL to use for the request.
    ///  - Returns: An `IdpClient` object containing the client information.
    public func fetch(httpClient: any HttpClientProtocol, url: URL?) async throws -> IdpClient {
        guard let url = url else {
            throw IdpExceptions.illegalArgumentException(message: "URL cannot be nil")
        }
        let response = try await httpClient.request { request in
            request.url = url.absoluteString
            request.setHeader(name: NetworkConstants.headerRequestedWith, value: NetworkConstants.requestedWithValue)
            request.setHeader(name: NetworkConstants.headerAccept, value: NetworkConstants.contentTypeJSON)
        }
        let idpClient = try IdpClient(response: response)
        return idpClient
    }
}

extension IdpClient {
    /// Initializes an `IdpClient` object from a `Response`.
    /// - Parameter response: The `Response` object to use for initialization.
    /// - Throws: if the response cannot be parsed.
    public init(response: HttpResponse) throws {
        self.init()
        let responseJson = try response.json()
        let idp: [String: Any]? = responseJson[NetworkConstants.idp] as? [String: Any]
        self.clientId = idp?[NetworkConstants.clientId] as? String
        self.nonce = idp?[NetworkConstants.nonce] as? String
        self.scopes = idp?[NetworkConstants.scopes] as? [String] ?? []
        let links: [String: Any]? = responseJson[NetworkConstants._links] as? [String: Any]
        let next = links?[NetworkConstants.next] as? [String: Any]
        let href = next?[NetworkConstants.href] as? String ?? ""
        self.redirectUri = idp?[NetworkConstants.redirectUri] as? String
        self.continueUrl = href
    }
}
