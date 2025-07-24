//
//  Response.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation


/// Represents an HTTP response.
public protocol Response {
    /// The original request that produced this response.
    var data: Data { get }
    
    /// Returns the body of the response.
    /// - Returns: The body as a String.
    func body() async -> String
    
    /// Returns the HTTP status code.
    /// - Returns: The status code as an Int.
    func status() -> Int
    
    /// Returns the cookies included in the response.
    /// - Returns: A `Cookies` container.
    func getCookies() -> [HTTPCookie]
    
    /// Returns the value of a header.
    /// - Parameter name: The name of the header.
    /// - Returns: The header value, or `nil` if not present.
    func header(name: String) -> String?
    
    /// Returns the body of the response as a JSON object.
    /// - Returns: The body of the response as a JSON object.
    func json() throws -> [String: Any]
}

extension Response {
    /// Returns the body of the response as a JSON object.
    /// - Returns: The body of the response as a JSON object.
    public func json() throws -> [String: Any] {
        return (try JSONSerialization.jsonObject(with: self.data, options: []) as? [String: Any]) ?? [:]
    }
}

/// Struct for a Response. A Response represents a response received from a network request.
/// - property data: The data  received from the network request.
/// - property response: The URLResponse received from the network request.
public struct HttpResponse: Response, @unchecked Sendable {
    public var data: Data
    public let response: URLResponse
    
    /// Initializes a new instance of `Response`.
    /// - Parameters:
    ///  - data: The data received from the network request.
    ///  - response: The URLResponse received from the network request.
    public init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }
    
    /// Returns the body of the response.
    /// - Returns: The body of the response as a String.
    public func body() -> String {
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    ///  Returns the status code of the response.
    /// - Returns: The status code of the response as an Int.
    public func status() -> Int {
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
    
    ///  Returns the value of a specific header from the response.
    /// - Parameter name: The name of the header.
    /// - Returns: The value of the header as a String.
    public func header(name: String) -> String? {
        return (response as? HTTPURLResponse)?.allHeaderFields[name] as? String
    }
    
    /// Returns the cookies from the response.
    /// - Returns: The cookies from the response as an array of HTTPCookie.
    public func getCookies() -> [HTTPCookie] {
        if let response = (response as? HTTPURLResponse),
           let allHeaders = response.allHeaderFields as? [String : String],
           let url = response.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: url)
            return cookies
        }
        return []
    }
    
    /// Constants used in the Response
    public enum Constants {
        public static let clientId = "clientId"
        public static let scopes = "scopes"
        public static let nonce = "nonce"
        public static let redirectUri = "redirectUri"
        public static let href = "href"
        public static let _links = "_links"
        public static let next = "next"
        public static let idp = "idp"
    }
}
