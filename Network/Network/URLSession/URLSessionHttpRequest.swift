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
    
    /// Adds a query parameter to the request URL.
    ///
    /// Multiple calls with the same parameter name will add multiple values.
    ///
    /// - Note: `+` in the value is percent-encoded as `%2B`. `URLQueryItem` leaves it raw,
    ///   and servers decode `application/x-www-form-urlencoded` values with `+` meaning
    ///   space — so a literal `+` (e.g. in phone numbers or JSON payloads) would otherwise
    ///   be silently corrupted to a space.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    public func setParameter(name: String, value: String) {
        var items = getQueryParameters()
        items.append(URLQueryItem(name: name, value: value))
        setQueryParameters(items)
    }

    // Helper to update urlRequest.url with new query parameters.
    //
    // `URLQueryItem` leaves `+` unencoded in values, but form-urlencoded (and many
    // query-string) decoders treat `+` as a space — a literal `+` in a value (phone
    // numbers, JSON payloads, base64 padding) would be silently corrupted. Re-encode
    // the query string with RFC 3986 rules (`+` → `%2B`) before applying it.
    private func setQueryParameters(_ items: [URLQueryItem]) {
        guard let url = urlRequest.url, !items.isEmpty else { return }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = rfc3986EncodedQuery(items)
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
        components.percentEncodedQuery = rfc3986EncodedQuery(items)
        if let data = components.percentEncodedQuery?.data(using: .utf8) {
            urlRequest.httpBody = data
        }
    }

    /// Serializes query items into a percent-encoded query string with RFC 3986 rules:
    /// everything except `A-Z a-z 0-9 - . _ ~` is percent-encoded — including `+`
    /// (which `URLComponents.queryItems` leaves raw, but form decoders read as space).
    /// The result is safe to assign to `URLComponents.percentEncodedQuery`.
    ///
    /// Note: an item with a `nil` value renders as `name=` (empty value). `URLComponents`
    /// would render it as a bare `name` with no `=` — servers distinguishing flag
    /// parameters from empty values will see the `=` form here.
    private func rfc3986EncodedQuery(_ items: [URLQueryItem]) -> String {
        func encode(_ raw: String) -> String {
            // `addingPercentEncoding` only fails on malformed/unpaired UTF-16 surrogates —
            // rare, but falling back to the raw string silently would regress exactly the
            // class of corruption this encoder exists to prevent (e.g. a raw `+` read back
            // as a space). Log it so a malformed input doesn't fail silently.
            guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: Self.rfc3986AllowedCharacters) else {
                logger.w("URLSessionHttpRequest: failed to percent-encode a query/form value; sending it unencoded, which may be corrupted by the server", error: nil)
                return raw
            }
            return encoded
        }
        return items.map { item in
            let value = encode(item.value ?? "")
            return "\(encode(item.name))=\(value)"
        }.joined(separator: "&")
    }

    /// Characters permitted unescaped in an RFC 3986 query component.
    private static let rfc3986AllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
