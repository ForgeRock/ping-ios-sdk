//
//  URLSessionHttpRequest.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// URLSession-based implementation of `HttpRequest`.
///
/// This type accumulates headers, query parameters, cookies, and bodies before
/// building a `URLRequest` for execution by the HTTP client.
public final class URLSessionHttpRequest: HttpRequest, @unchecked Sendable {
    public var url: String?

    private var headers: [String: String] = [:]
    private var parameters: [URLQueryItem] = []
    private var cookies: [String] = []
    private var method: HttpMethod = .get
    private var bodyData: Data?
    private var formParameters: [URLQueryItem] = []
    private var jsonError: Error?

    /// Creates a new HTTP request with standard headers automatically injected.
    ///
    /// Standard headers include:
    /// - `x-requested-with: ping-sdk`
    /// - `x-requested-platform: ios`
    public init() {
        headers[NetworkConstants.headerRequestedWith] = NetworkConstants.requestedWithValue
        headers[NetworkConstants.headerRequestedPlatform] = NetworkConstants.requestedPlatformValue
    }

    /// Adds a query parameter to the request URL.
    ///
    /// Multiple calls with the same parameter name will add multiple values.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    public func setParameter(name: String, value: String) {
        parameters.append(URLQueryItem(name: name, value: value))
    }

    /// Sets a header value for the request.
    ///
    /// If the header already exists (case-insensitive comparison), it will be replaced.
    ///
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    public func setHeader(name: String, value: String) {
        headers = headers.filter { $0.key.lowercased() != name.lowercased() }
        headers[name] = value
    }

    /// Adds a cookie to the request.
    ///
    /// - Parameter cookie: The cookie string to add.
    public func setCookie(cookie: String) {
        cookies.append(cookie)
    }

    /// Adds multiple cookies to the request.
    ///
    /// - Parameter cookies: Array of cookie strings to add.
    public func setCookies(cookies: [String]) {
        self.cookies.append(contentsOf: cookies)
    }

    /// Configures the request as a GET request.
    ///
    /// Clears any previously set body data.
    public func get() {
        method = .get
        bodyData = nil
    }

    /// Configures the request as a POST request with a JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func post(json: [String: Any] = [:]) {
        method = .post
        bodyData = serializeSafely(json)
        headers[NetworkConstants.headerContentType] = NetworkConstants.contentTypeJSON
    }

    /// Configures the request as a PUT request with a JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func put(json: [String: Any] = [:]) {
        method = .put
        bodyData = serializeSafely(json)
        headers[NetworkConstants.headerContentType] = NetworkConstants.contentTypeJSON
    }

    /// Configures the request as a DELETE request with an optional JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func delete(json: [String: Any] = [:]) {
        method = .delete
        bodyData = serializeSafely(json)
        headers[NetworkConstants.headerContentType] = NetworkConstants.contentTypeJSON
    }

    /// Configures the request as a POST request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func post(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        method = .post
        bodyData = Data(body.utf8)
        headers[NetworkConstants.headerContentType] = contentType
    }

    /// Configures the request as a PUT request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func put(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        method = .put
        bodyData = Data(body.utf8)
        headers[NetworkConstants.headerContentType] = contentType
    }

    /// Configures the request as a DELETE request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func delete(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        method = .delete
        bodyData = Data(body.utf8)
        headers[NetworkConstants.headerContentType] = contentType
    }

    /// Configures the request as a POST request with form-encoded data.
    ///
    /// Multiple calls to `form()` will accumulate parameters. Sets Content-Type to
    /// `application/x-www-form-urlencoded`.
    ///
    /// - Parameter parameters: Dictionary of form field names and values.
    public func form(parameters: [String: String]) {
        method = .post
        for (key, value) in parameters {
            formParameters.append(URLQueryItem(name: key, value: value))
        }
        buildFormBody()
    }

    /// Sets the HTTP method directly.
    ///
    /// - Parameter method: The HTTP method to use (GET, POST, PUT, DELETE, etc.).
    public func setMethod(_ method: HttpMethod) {
        self.method = method
    }

    /// Sets the request body directly as raw data.
    ///
    /// Clears any JSON serialization errors.
    ///
    /// - Parameter body: The body data, or nil to clear the body.
    public func setBody(_ body: Data?) {
        jsonError = nil
        bodyData = body
    }

    /// Gets the currently configured HTTP method.
    ///
    /// - Returns: The configured HTTP method.
    public func getMethod() -> HttpMethod {
        method
    }

    /// Gets a header value by name.
    ///
    /// Performs case-insensitive header name lookup.
    ///
    /// - Parameter name: The header name to look up.
    /// - Returns: The header value, or nil if not set.
    public func getHeader(name: String) -> String? {
        headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }

    /// Gets all headers as a dictionary.
    ///
    /// - Returns: Dictionary of header names to values.
    public func getHeaders() -> [String: String] {
        headers
    }

    /// Builds a `URLRequest` from the accumulated request state.
    /// - Returns: A configured `URLRequest`, or `nil` if no URL is set.
    public func buildURLRequest() -> URLRequest? {
        guard jsonError == nil else { return nil }
        guard let urlString = url, let baseURL = URL(string: urlString) else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        if !parameters.isEmpty {
            var items = components?.queryItems ?? []
            items.append(contentsOf: parameters)
            components?.queryItems = items
        }
        guard let finalURL = components?.url else { return nil }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = bodyData

        var appliedHeaders = headers
        if !cookies.isEmpty {
            let cookieHeader = cookies.joined(separator: "; ")
            appliedHeaders[NetworkConstants.headerCookie] = cookieHeader
        }
        for (name, value) in appliedHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        return request
    }

    private func buildFormBody() {
        var components = URLComponents()
        components.queryItems = formParameters
        bodyData = components.percentEncodedQuery?.data(using: .utf8)
        headers[NetworkConstants.headerContentType] = NetworkConstants.contentTypeForm
    }

    private func serializeSafely(_ json: [String: Any]) -> Data? {
        do {
            jsonError = nil
            if json.isEmpty {
                return Data("{}".utf8)
            }
            guard JSONSerialization.isValidJSONObject(json) else {
                jsonError = NetworkError.invalidRequest("Invalid JSON body")
                return nil
            }
            return try serializeJSON(json)
        } catch {
            jsonError = error
            return nil
        }
    }

    private func serializeJSON(_ dict: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}
