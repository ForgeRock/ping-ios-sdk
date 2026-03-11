//
//  URLSessionHttpRequest.swift
//  PingNetwork
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// URLSession-based implementation of `HttpRequest`.
///
/// This type accumulates headers, query parameters, cookies, and bodies before
/// building a `URLRequest` for execution by the HTTP client.
///
/// **This class is NOT thread-safe.** It contains mutable state without synchronization
/// and should not be shared across multiple threads or modified concurrently.
public class URLSessionHttpRequest: HttpRequest, @unchecked Sendable {
    
    var logger: Logger
    
    /// The target URL for this HTTP request.
    public var url: String? {
        get {
            urlRequest.url?.absoluteString
        }
        set {
            if let urlString = newValue, let newURL = URL(string: urlString) {
                urlRequest.url = newURL
            } else {
                urlRequest.url = nil
            }
        }
    }
    
    private var urlRequest: URLRequest
    
    /// Tracks whether JSON serialization failed during body configuration.
    private var jsonSerializationFailed: Bool = false

    /// Creates a new HTTP request with standard headers automatically injected.
    ///
    /// Standard headers include:
    /// - `x-requested-with: ping-sdk`
    /// - `x-requested-platform: ios`
    ///
    /// - Parameter logger: The logger to use for this request. Defaults to `LogManager.logger`.
    public init(logger: Logger = LogManager.logger) {
        self.logger = logger
        // Initialize with a placeholder URL - will be replaced when buildURLRequest is called
        urlRequest = URLRequest(url: URL(string: "https://")!)
        urlRequest.httpMethod = HttpMethod.get.rawValue
        urlRequest.setValue(NetworkConstants.requestedWithValue, forHTTPHeaderField: NetworkConstants.headerRequestedWith)
        urlRequest.setValue(NetworkConstants.requestedPlatformValue, forHTTPHeaderField: NetworkConstants.headerRequestedPlatform)
    }

    /// Adds a query parameter to the request URL.
    ///
    /// Multiple calls with the same parameter name will add multiple values.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    public func setParameter(name: String, value: String) {
        var items = getQueryParameters()
        items.append(URLQueryItem(name: name, value: value))
        setQueryParameters(items)
    }

    /// Sets a header value for the request.
    ///
    /// If the header already exists (case-insensitive comparison), it will be replaced.
    ///
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    public func setHeader(name: String, value: String) {
        // Remove existing header with same name (case-insensitive)
        if let allHeaders = urlRequest.allHTTPHeaderFields {
            for (key, _) in allHeaders where key.lowercased() == name.lowercased() {
                urlRequest.setValue(nil, forHTTPHeaderField: key)
            }
        }
        urlRequest.setValue(value, forHTTPHeaderField: name)
    }

    /// Adds a cookie to the request.
    ///
    /// - Parameter cookie: The cookie string to add.
    public func setCookie(cookie: String) {
        var currentCookies = getCookies()
        currentCookies.append(cookie)
        setCookiesHeader(currentCookies)
    }

    /// Adds multiple cookies to the request.
    ///
    /// - Parameter cookies: Array of cookie strings to add.
    public func setCookies(cookies: [String]) {
        var currentCookies = getCookies()
        currentCookies.append(contentsOf: cookies)
        setCookiesHeader(currentCookies)
    }

    /// Configures the request as a GET request.
    ///
    /// Clears any previously set body data.
    public func get() {
        urlRequest.httpMethod = HttpMethod.get.rawValue
        urlRequest.httpBody = nil
    }

    /// Configures the request as a POST request with a JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func post(json: [String: Any] = [:]) {
        urlRequest.httpMethod = HttpMethod.post.rawValue
        urlRequest.httpBody = serializeJSON(json)
        setHeader(name: NetworkConstants.headerContentType, value: NetworkConstants.contentTypeJSON)
    }

    /// Configures the request as a PUT request with a JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func put(json: [String: Any] = [:]) {
        urlRequest.httpMethod = HttpMethod.put.rawValue
        urlRequest.httpBody = serializeJSON(json)
        setHeader(name: NetworkConstants.headerContentType, value: NetworkConstants.contentTypeJSON)
    }

    /// Configures the request as a DELETE request with an optional JSON body.
    ///
    /// The dictionary will be serialized to JSON. Sets Content-Type to `application/json`.
    ///
    /// - Parameter json: The dictionary to serialize as JSON. Defaults to empty dictionary.
    public func delete(json: [String: Any] = [:]) {
        urlRequest.httpMethod = HttpMethod.delete.rawValue
        urlRequest.httpBody = serializeJSON(json)
        setHeader(name: NetworkConstants.headerContentType, value: NetworkConstants.contentTypeJSON)
    }

    /// Configures the request as a POST request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func post(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        urlRequest.httpMethod = HttpMethod.post.rawValue
        urlRequest.httpBody = Data(body.utf8)
        setHeader(name: NetworkConstants.headerContentType, value: contentType)
    }

    /// Configures the request as a PUT request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func put(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        urlRequest.httpMethod = HttpMethod.put.rawValue
        urlRequest.httpBody = Data(body.utf8)
        setHeader(name: NetworkConstants.headerContentType, value: contentType)
    }

    /// Configures the request as a DELETE request with a string body.
    ///
    /// - Parameters:
    ///   - contentType: The Content-Type header value. Defaults to `application/json`.
    ///   - body: The string body to send.
    public func delete(contentType: String = NetworkConstants.contentTypeJSON, body: String) {
        urlRequest.httpMethod = HttpMethod.delete.rawValue
        urlRequest.httpBody = Data(body.utf8)
        setHeader(name: NetworkConstants.headerContentType, value: contentType)
    }

    /// Configures the request as a POST request with form-encoded data.
    ///
    /// Multiple calls to `form()` will accumulate parameters. Sets Content-Type to
    /// `application/x-www-form-urlencoded`.
    ///
    /// - Parameter parameters: Dictionary of form field names and values.
    public func form(parameters: [String: String]) {
        urlRequest.httpMethod = HttpMethod.post.rawValue
        
        // Get existing form parameters and add new ones
        var items = getFormParameters()
        for (key, value) in parameters {
            items.append(URLQueryItem(name: key, value: value))
        }
        setFormParameters(items)
        
        setHeader(name: NetworkConstants.headerContentType, value: NetworkConstants.contentTypeForm)
    }

    /// Sets the HTTP method directly.
    ///
    /// - Parameter method: The HTTP method to use (GET, POST, PUT, DELETE, etc.).
    public func setMethod(_ method: HttpMethod) {
        urlRequest.httpMethod = method.rawValue
    }

    /// Sets the request body directly as raw data.
    ///
    /// Clears any JSON serialization errors.
    ///
    /// - Parameter body: The body data, or nil to clear the body.
    public func setBody(_ body: Data?) {
        urlRequest.httpBody = body
        jsonSerializationFailed = false
    }

    /// Gets the currently configured HTTP method.
    ///
    /// - Returns: The configured HTTP method.
    public func getMethod() -> HttpMethod {
        HttpMethod(rawValue: urlRequest.httpMethod ?? "GET") ?? .get
    }

    /// Gets a header value by name.
    ///
    /// Performs case-insensitive header name lookup.
    ///
    /// - Parameter name: The header name to look up.
    /// - Returns: The header value, or nil if not set.
    public func getHeader(name: String) -> String? {
        urlRequest.value(forHTTPHeaderField: name)
    }

    /// Gets all headers as a dictionary.
    ///
    /// - Returns: Dictionary of header names to values.
    public func getHeaders() -> [String: String] {
        urlRequest.allHTTPHeaderFields ?? [:]
    }

    /// Builds a `URLRequest` from the accumulated request state.
    ///
    /// This method constructs a complete `URLRequest` by:
    /// - Using the URL with already-accumulated query parameters
    /// - Applying the HTTP method, headers, and body
    ///
    /// - Returns: A configured `URLRequest`, or `nil` if the URL is invalid or JSON serialization failed.
    public func buildURLRequest() -> URLRequest? {
        if jsonSerializationFailed {
            return nil
        }
        
        // urlRequest.url already contains all query parameters, so just use it directly
        guard let finalURL = urlRequest.url else { return nil }

        // Create final request with the complete URL
        var request = URLRequest(url: finalURL)
        request.httpMethod = urlRequest.httpMethod
        request.allHTTPHeaderFields = urlRequest.allHTTPHeaderFields
        request.httpBody = urlRequest.httpBody

        return request
    }
}

/// Private helper methods
extension URLSessionHttpRequest {
    // Helper to serialize a JSON dictionary to Data 
    private func serializeJSON(_ json: [String: Any]) -> Data? {
        if json.isEmpty {
            return Data("{}".utf8)
        }
        
        guard JSONSerialization.isValidJSONObject(json) else {
            jsonSerializationFailed = true
            logger.d("URLSessionHttpRequest: Invalid JSON object for serialization.")
            return nil
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            jsonSerializationFailed = true
            logger.d("URLSessionHttpRequest: JSON serialization failed.")
            return nil
        }
        
        return data
    }
    
    // Helper to extract query parameters from urlRequest.url
    private func getQueryParameters() -> [URLQueryItem] {
        guard let url = urlRequest.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return []
        }
        return items
    }
    
    // Helper to update urlRequest.url with new query parameters
    private func setQueryParameters(_ items: [URLQueryItem]) {
        guard let url = urlRequest.url else { return }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = items.isEmpty ? nil : items
        if let newURL = components?.url {
            urlRequest.url = newURL
        }
    }
    
    // Helper to get current cookies from Cookie header
    private func getCookies() -> [String] {
        guard let cookieHeader = urlRequest.value(forHTTPHeaderField: NetworkConstants.headerCookie) else {
            return []
        }
        return cookieHeader.components(separatedBy: "; ")
    }
    
    // Helper to set cookies in Cookie header
    private func setCookiesHeader(_ cookies: [String]) {
        if cookies.isEmpty {
            urlRequest.setValue(nil, forHTTPHeaderField: NetworkConstants.headerCookie)
        } else {
            urlRequest.setValue(cookies.joined(separator: "; "), forHTTPHeaderField: NetworkConstants.headerCookie)
        }
    }
    
    // Helper to get form parameters from body
    private func getFormParameters() -> [URLQueryItem] {
        guard let body = urlRequest.httpBody,
              let bodyString = String(data: body, encoding: .utf8) else {
            return []
        }
        var components = URLComponents()
        components.percentEncodedQuery = bodyString
        return components.queryItems ?? []
    }
    
    // Helper to set form parameters in body
    private func setFormParameters(_ items: [URLQueryItem]) {
        var components = URLComponents()
        components.queryItems = items
        if let data = components.percentEncodedQuery?.data(using: .utf8) {
            urlRequest.httpBody = data
        }
    }
}
