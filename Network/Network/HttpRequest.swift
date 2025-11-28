//
//  HttpRequest.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol defining the contract for building HTTP requests.
///
/// `HttpRequest` provides a fluent interface for configuring HTTP requests
/// including URL, headers, query parameters, cookies, and request body.
public protocol HttpRequest: Sendable {
    /// The URL for this request.
    var url: String? { get set }

    /// Adds a query parameter to the request URL.
    ///
    /// Multiple calls with the same parameter name will add multiple values.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    func setParameter(name: String, value: String)

    /// Sets a header value for the request.
    ///
    /// If the header already exists, it will be replaced.
    ///
    /// - Parameters:
    ///   - name: The header name (case-insensitive).
    ///   - value: The header value.
    func setHeader(name: String, value: String)

    /// Adds a cookie to the request.
    ///
    /// - Parameter cookie: The cookie string to add.
    func setCookie(cookie: String)

    /// Adds multiple cookies to the request.
    ///
    /// - Parameter cookies: Array of cookie strings.
    func setCookies(cookies: [String])

    /// Configures the request as a GET request.
    func get()

    /// Configures the request as a POST request with JSON body.
    ///
    /// - Parameter json: Dictionary to serialize as JSON.
    func post(json: [String: Any])

    /// Configures the request as a PUT request with JSON body.
    ///
    /// - Parameter json: Dictionary to serialize as JSON.
    func put(json: [String: Any])

    /// Configures the request as a DELETE request with JSON body.
    ///
    /// - Parameter json: Dictionary to serialize as JSON.
    func delete(json: [String: Any])

    /// Configures the request as a POST request with a raw string body.
    ///
    /// - Parameters:
    ///   - contentType: Content-Type header value. Defaults to application/json to align with Android.
    ///   - body: String payload to encode as UTF-8.
    func post(contentType: String, body: String)

    /// Configures the request as a PUT request with a raw string body.
    ///
    /// - Parameters:
    ///   - contentType: Content-Type header value. Defaults to application/json to align with Android.
    ///   - body: String payload to encode as UTF-8.
    func put(contentType: String, body: String)

    /// Configures the request as a DELETE request with a raw string body.
    ///
    /// - Parameters:
    ///   - contentType: Content-Type header value. Defaults to application/json to align with Android.
    ///   - body: String payload to encode as UTF-8.
    func delete(contentType: String, body: String)

    /// Configures the request as a POST with form-encoded data.
    ///
    /// Multiple calls to `form()` will accumulate parameters.
    ///
    /// - Parameter parameters: Dictionary of form field names and values.
    func form(parameters: [String: String])

    /// Sets the HTTP method directly.
    ///
    /// - Parameter method: The HTTP method to use.
    func setMethod(_ method: HttpMethod)

    /// Sets the request body directly.
    ///
    /// - Parameter body: The body data.
    func setBody(_ body: Data?)

    /// Gets the current HTTP method.
    ///
    /// - Returns: The configured HTTP method.
    func getMethod() -> HttpMethod

    /// Gets a header value by name.
    ///
    /// - Parameter name: The header name (case-insensitive).
    /// - Returns: The header value, or nil if not set.
    func getHeader(name: String) -> String?

    /// Gets all headers as a dictionary.
    ///
    /// - Returns: Dictionary of header names to values.
    func getHeaders() -> [String: String]
}
