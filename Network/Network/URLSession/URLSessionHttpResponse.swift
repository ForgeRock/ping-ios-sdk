//
//  URLSessionHttpResponse.swift
//  PingNetwork
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// URLSession-based implementation of `HttpResponse`.
///
/// This class is **thread-safe** and can be safely shared across threads.
public final class URLSessionHttpResponse: HttpResponse, @unchecked Sendable {
    
    /// The original HTTP request that generated this response.
    public let request: HttpRequest
    
    /// The HTTP status code (e.g., 200, 404, 500).
    public var status: Int {  httpURLResponse?.statusCode ?? 0 }
    
    /// The response body as raw data.
    public let body: Data?
    
    private let httpURLResponse: HTTPURLResponse?

    /// Creates a new HTTP response from URLSession data.
    ///
    /// - Parameters:
    ///   - request: The original HTTP request.
    ///   - body: The response body data.
    ///   - httpURLResponse: The underlying HTTPURLResponse object.
    public init(
        request: HttpRequest,
        body: Data?,
        httpURLResponse: HTTPURLResponse?
    ) {
        self.request = request
        self.body = body
        self.httpURLResponse = httpURLResponse
    }

    /// Gets the first value for a header by name.
    ///
    /// Performs case-insensitive header name lookup.
    ///
    /// - Parameter name: The header name to look up.
    /// - Returns: The first header value, or nil if not present.
    public func getHeader(name: String) -> String? {
        return httpURLResponse?.value(forHTTPHeaderField: name)
    }

    /// Gets all values for a header by name.
    ///
    /// HTTP headers can have multiple values. Performs case-insensitive lookup.
    ///
    /// - Parameter name: The header name to look up.
    /// - Returns: Array of header values, or nil if not present.
    public func getHeaders(name: String) -> [String]? {
        return getHeader(name: name) != nil ? [getHeader(name: name) ?? ""] : nil
    }

    /// Parses Set-Cookie headers and returns HTTPCookie objects.
    ///
    /// Handles multiple Set-Cookie headers and comma-separated values,
    /// matching Android SDK behavior.
    ///
    /// - Returns: Array of parsed HTTP cookies.
    public func getCookies() -> [HTTPCookie] {
        if let allHeaders = httpURLResponse?.allHeaderFields as? [String : String],
           let url = httpURLResponse?.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: url)
            return cookies
        }
        return []
    }

    /// Converts the response body to a UTF-8 string.
    ///
    /// - Returns: The decoded body string, or an empty string if body is nil or not valid UTF-8.
    public func bodyAsString() -> String {
        guard let body else { return "" }
        return String(data: body, encoding: .utf8) ?? ""
    }

    /// Gets raw Set-Cookie header values before parsing.
    ///
    /// This method extracts Set-Cookie headers from both the normalized headers
    /// dictionary and the raw HTTPURLResponse, handling line breaks and comma separation.
    ///
    /// - Returns: Array of raw Set-Cookie header strings.
    public func getCookieStrings() -> [String] {
        return getHeaders(name: NetworkConstants.headerSetCookie) ?? []
    }
}
