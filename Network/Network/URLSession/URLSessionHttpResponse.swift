//
//  URLSessionHttpResponse.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
    public let status: Int
    
    /// The response body as raw data.
    public let body: Data?
    
    /// All response headers with case-insensitive normalized keys.
    public let headers: [String: [String]]

    private let httpURLResponse: HTTPURLResponse?

    /// Creates a new HTTP response from URLSession data.
    ///
    /// - Parameters:
    ///   - request: The original HTTP request.
    ///   - status: The HTTP status code.
    ///   - headers: Response headers dictionary.
    ///   - body: The response body data.
    ///   - httpURLResponse: The underlying HTTPURLResponse object.
    public init(
        request: HttpRequest,
        status: Int,
        headers: [String: [String]],
        body: Data?,
        httpURLResponse: HTTPURLResponse?
    ) {
        self.request = request
        self.status = status
        self.headers = Self.normalize(headers)
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
        getHeaders(name: name)?.first
    }

    /// Gets all values for a header by name.
    ///
    /// HTTP headers can have multiple values. Performs case-insensitive lookup.
    ///
    /// - Parameter name: The header name to look up.
    /// - Returns: Array of header values, or nil if not present.
    public func getHeaders(name: String) -> [String]? {
        headers[name.lowercased()]
    }

    /// Parses Set-Cookie headers and returns HTTPCookie objects.
    ///
    /// Handles multiple Set-Cookie headers and comma-separated values,
    /// matching Android SDK behavior.
    ///
    /// - Returns: Array of parsed HTTP cookies.
    public func getCookies() -> [HTTPCookie] {
        guard let url = resolvedURL() else { return [] }
        return getCookieStrings()
            .flatMap { parseCookies(from: $0, url: url) }
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
        let headerValues = headers[NetworkConstants.headerSetCookieLowercased] ?? []
        let splitValues = headerValues.flatMap { value -> [String] in
            value
                .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let responseValue = httpURLResponse?.allHeaderFields[NetworkConstants.headerSetCookie] as? String {
            return splitValues + [responseValue]
        }
        return splitValues
    }

    private func parseCookies(from headerValue: String, url: URL) -> [HTTPCookie] {
        let values = headerValue
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if values.isEmpty {
            return HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": headerValue], for: url)
        }
        return values.flatMap {
            HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": $0], for: url)
        }
    }

    private func resolvedURL() -> URL? {
        if let url = httpURLResponse?.url {
            return url
        }
        if let requestURLString = (request as? URLSessionHttpRequest)?.url {
            return URL(string: requestURLString)
        }
        return nil
    }

    private static func normalize(_ headers: [String: [String]]) -> [String: [String]] {
        headers.reduce(into: [String: [String]]()) { result, pair in
            let key = pair.key.lowercased()
            let values = pair.value
            var existing = result[key] ?? []
            existing.append(contentsOf: values)
            result[key] = existing
        }
    }
}
