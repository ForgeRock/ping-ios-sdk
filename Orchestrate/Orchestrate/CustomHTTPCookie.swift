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
public struct CustomHTTPCookie: Codable, Sendable {
    public var version: Int
    public var name: String?
    public var value: String?
    public var expiresDate: Date?
    public var isSessionOnly: Bool
    public var domain: String?
    public var path: String?
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var comment: String?
    public var commentURL: URL?
    public var portList: [Int]?
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
    /// - Returns: An `HTTPCookie` instance.
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
