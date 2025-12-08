//
//  UriScheme.swift
//  PingCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Supported URI Schemes for MFA
public enum UriScheme: String, CaseIterable, Sendable {

    /// Standard URI scheme for OTP (One-Time Password) authentication
    case otpauth = "otpauth://"
    /// URI scheme for Push Authentication
    case pushauth = "pushauth://"
    /// URI scheme for Combined Multi-Factor Authentication (Push & OTP)
    case mfauth = "mfauth://"

    /// The scheme string without the "://" suffix.
    public var scheme: String {
        String(rawValue.dropLast(3))
    }

    /// Creates a `UriScheme` from a URL string.
    /// - Parameter urlString: The URL string to parse.
    /// - Returns: The matching `UriScheme`, or `nil` if no match found.
    public static func from(urlString: String) -> UriScheme? {
        let lowercased = urlString.lowercased()
        return UriScheme.allCases.first { lowercased.hasPrefix($0.rawValue.lowercased()) }
    }

    /// Creates a `UriScheme` from a URL.
    /// - Parameter url: The URL to parse.
    /// - Returns: The matching `UriScheme`, or `nil` if no match found.
    public static func from(url: URL) -> UriScheme? {
        guard let scheme = url.scheme else { return nil }
        let schemeWithSeparator = "\(scheme)://"
        return UriScheme.allCases.first { $0.rawValue.lowercased() == schemeWithSeparator.lowercased() }
    }

    /// Checks if a URL string matches this scheme.
    /// - Parameter urlString: The URL string to check.
    /// - Returns: `true` if the URL string starts with this scheme.
    public func matches(urlString: String) -> Bool {
        urlString.lowercased().hasPrefix(rawValue.lowercased())
    }

    /// Checks if a URL matches this scheme.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL uses this scheme.
    public func matches(url: URL) -> Bool {
        guard let urlScheme = url.scheme else { return false }
        return scheme.lowercased() == urlScheme.lowercased()
    }
}
