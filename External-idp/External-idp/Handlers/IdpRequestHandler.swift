//
//  IdpRequestHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Interface representing an Identity Provider (IdP) handler.
public protocol IdpRequestHandler {
    /// The type of token to use for the IdP.
    var tokenType: String { get set }
    
    /// Authorizes the user with the IdP.
    /// - Parameter url: The URL to use for authorization.
    /// - Returns: A `Request` object containing the result of the authorization
    func authorize(url: URL?) async throws -> Request
    /// Fetch the IdP client information from the server
    /// - Parameters:
    ///  - httpClient: The `HttpClient` to use for the request.
    ///  - url: The URL to use for the request.
    ///  - Returns: An `IdpClient` object containing the client information.
    func fetch(httpClient: HttpClient, url: URL?) async throws -> IdpClient
}

extension IdpRequestHandler {
    /// Fetch the IdP client information from the server
    /// - Parameters:
    ///  - httpClient: The `HttpClient` to use for the request.
    ///  - url: The URL to use for the request.
    ///  - Returns: An `IdpClient` object containing the client information.
    public func fetch(httpClient: HttpClient, url: URL?) async throws -> IdpClient {
        guard let url = url else {
            throw IdpExceptions.illegalArgumentException(message: "URL cannot be nil")
        }
        let request = Request(urlString: url.absoluteString)
        request.header(name: Request.Constants.xRequestedWith, value: Request.Constants.pingSdk)
        request.header(name: Request.Constants.accept, value: Request.ContentType.json.rawValue)
        let (data, urlResponse) = try await httpClient.sendRequest(request: request)
        let response = Response(data: data, response: urlResponse)
        let idpClient = try IdpClient(response: response)
        return idpClient
    }
}

extension IdpClient {
    /// Initializes an `IdpClient` object from a `Response`.
    /// - Parameter response: The `Response` object to use for initialization.
    /// - Throws: if the response cannot be parsed.
    public init(response: Response) throws {
        self.init()
        let responseJson = try response.json(data: response.data)
        let idp: [String: Any]? = responseJson[Response.Constants.idp] as? [String: Any]
        self.clientId = idp?[Response.Constants.clientId] as? String
        self.nonce = idp?[Response.Constants.nonce] as? String
        self.scopes = idp?[Response.Constants.scopes] as? [String] ?? []
        let links: [String: Any]? = responseJson[Response.Constants._links] as? [String: Any]
        let next = links?[Response.Constants.next] as? [String: Any]
        let href = next?[Response.Constants.href] as? String ?? ""
        self.redirectUri = idp?[Response.Constants.redirectUri] as? String
        self.continueUrl = href
    }
}
