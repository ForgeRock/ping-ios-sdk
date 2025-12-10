//
//  CustomHTTPCookie.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A struct that represents a custom HTTP cookie.
///
/// `CustomHTTPCookie` provides a `Codable` and `Sendable` representation of HTTP cookies,
/// allowing cookies to be easily serialized, deserialized, and safely passed across concurrency boundaries.
/// This type mirrors the properties of `HTTPCookie` but with full encoding and decoding support.
///
/// Use this type when you need to persist cookies or transfer them in a structured format,
/// such as saving to disk or sending across network boundaries.
public struct CustomHTTPCookie: Codable, Sendable {
    /// The version of the HTTP cookie specification to which this cookie conforms.
    ///
    /// Version 0 corresponds to the original Netscape cookie specification.
    /// Version 1 corresponds to RFC 2965.
    public var version: Int
    
    /// The name of the cookie.
    public var name: String?
    
    /// The value of the cookie.
    public var value: String?
    
    /// The expiration date of the cookie.
    ///
    /// If `nil`, the cookie has no expiration date. Session-only cookies typically have no expiration date.
    public var expiresDate: Date?
    
    /// A Boolean value that indicates whether the cookie should be discarded at the end of the session.
    ///
    /// Session-only cookies are deleted when the browser or application is closed.
    public var isSessionOnly: Bool
    
    /// The domain of the cookie.
    ///
    /// The domain determines which hosts can receive the cookie. If not specified,
    /// it defaults to the host that set the cookie.
    public var domain: String?
    
    /// The path on the server to which the cookie applies.
    ///
    /// Only requests to URLs within this path will include the cookie in the request headers.
    public var path: String?
    
    /// A Boolean value that indicates whether the cookie should only be sent over secure connections.
    ///
    /// When `true`, the cookie will only be sent over HTTPS connections.
    public var isSecure: Bool
    
    /// A Boolean value that indicates whether the cookie is accessible only through HTTP(S) protocols.
    ///
    /// When `true`, the cookie cannot be accessed through client-side scripts, providing protection
    /// against cross-site scripting (XSS) attacks.
    public var isHTTPOnly: Bool
    
    /// A comment associated with the cookie.
    ///
    /// This property is part of the RFC 2965 specification and provides human-readable information
    /// about the cookie's purpose.
    public var comment: String?
    
    /// A URL that provides additional information about the cookie.
    ///
    /// This property is part of the RFC 2965 specification and points to a privacy policy
    /// or other documentation about the cookie's use.
    public var commentURL: URL?
    
    /// The ports to which the cookie may be sent.
    ///
    /// If `nil`, the cookie can be sent to any port. If specified, the cookie will only be sent
    /// to the listed ports.
    public var portList: [Int]?
    
    /// The same-site policy for the cookie.
    ///
    /// This determines whether the cookie is sent with cross-site requests. Possible values include:
    /// - `"strict"`: The cookie is only sent in a first-party context
    /// - `"lax"`: The cookie is sent with top-level navigations and same-site requests
    /// - `"none"`: The cookie is sent with all requests (requires `isSecure` to be `true`)
    public var sameSitePolicy: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case name
        case value
        case expiresDate
        case isSessionOnly
        case domain
        case path
        case isSecure
        case isHTTPOnly
        case comment
        case commentURL
        case portList
        case sameSitePolicy
    }
    
    /// Initializes a `CustomHTTPCookie` from an `HTTPCookie`.
    ///
    /// This initializer creates a custom cookie representation by copying all relevant properties
    /// from the provided `HTTPCookie` instance. This is useful when you need to persist or serialize
    /// cookies that are received from HTTP responses.
    ///
    /// - Parameter cookie: The `HTTPCookie` to initialize from.
    public init(from cookie: HTTPCookie) {
        self.version = cookie.version
        self.name = cookie.name
        self.value = cookie.value
        self.expiresDate = cookie.expiresDate
        self.isSessionOnly = cookie.isSessionOnly
        self.domain = cookie.domain
        self.path = cookie.path
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
        self.comment = cookie.comment
        self.commentURL = cookie.commentURL
        self.portList = cookie.portList?.map { $0.intValue }
        self.sameSitePolicy = cookie.sameSitePolicy?.rawValue
    }
    
    /// Converts the `CustomHTTPCookie` to an `HTTPCookie`.
    ///
    /// This method reconstructs an `HTTPCookie` instance from the custom cookie properties.
    /// This is useful when you need to use a stored or transmitted cookie with Foundation's
    /// networking APIs.
    ///
    /// - Returns: An `HTTPCookie` instance if the properties are valid, or `nil` if the cookie
    ///            cannot be created (for example, if required properties like name or domain are missing).
    public func toHTTPCookie() -> HTTPCookie? {
        var properties = [HTTPCookiePropertyKey: Any]()
        properties[.version] = self.version
        properties[.name] = self.name
        properties[.value] = self.value
        properties[.expires] = self.expiresDate
        properties[.discard] = self.isSessionOnly ? Constants.true : nil
        properties[.domain] = self.domain
        properties[.path] = self.path
        properties[.secure] = self.isSecure ? Constants.true : nil
        properties[HTTPCookiePropertyKey(Constants.httpOnly)] = self.isHTTPOnly ? Constants.true : nil
        properties[.comment] = self.comment
        properties[.commentURL] = self.commentURL
        properties[.port] = self.portList?.map { NSNumber(value: $0) }
        
        if let sameSitePolicyValue = self.sameSitePolicy {
            properties[HTTPCookiePropertyKey.sameSitePolicy] = HTTPCookieStringPolicy(rawValue: sameSitePolicyValue)
        }
        
        return HTTPCookie(properties: properties)
    }
    
    enum Constants {
        static let `true` = "TRUE"
        static let httpOnly = "HttpOnly"
    }
}
