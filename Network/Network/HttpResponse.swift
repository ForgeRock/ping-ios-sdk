//
//  HttpResponse.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol defining the contract for HTTP responses.
///
/// `HttpResponse` provides access to the response status, headers, body,
/// and cookies from an HTTP request.
public protocol HttpResponse: Sendable {
    /// The original request that generated this response.
    var request: HttpRequest { get }

    /// The HTTP status code (e.g., 200, 404, 500).
    var status: Int { get }

    /// The response body as raw data.
    var body: Data? { get }

    /// All response headers as a dictionary.
    var headers: [String: [String]] { get }

    /// Gets a specific header value by name.
    ///
    /// - Parameter name: The header name (case-insensitive).
    /// - Returns: The header value, or nil if not present.
    func getHeader(name: String) -> String?

    /// Gets all header values by name.
    ///
    /// - Parameter name: The header name (case-insensitive).
    /// - Returns: Array of header values or nil if not present.
    func getHeaders(name: String) -> [String]?

    /// Gets all cookies from the response.
    ///
    /// - Returns: Array of cookies from Set-Cookie headers.
    func getCookies() -> [HTTPCookie]

    /// Gets raw Set-Cookie header strings.
    ///
    /// - Returns: Array of raw Set-Cookie header values.
    func getCookieStrings() -> [String]

    /// Gets the response body as a UTF-8 string.
    ///
    /// - Returns: The body as a string, or empty string if body is nil or invalid UTF-8.
    func bodyAsString() -> String
}
