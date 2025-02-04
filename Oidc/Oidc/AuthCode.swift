//
//  AuthCode.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct representing an authorization code.
public struct AuthCode: Codable {
    public let code: String
    public let codeVerifier: String?
  
    /// Initializes a new instance of `AuthCode`.
    /// - Parameters:
    ///   - code: The authorization code as a string. Default is an empty string.
    ///   - codeVerifier: An optional code verifier associated with the authorization code. Default is `nil`.
    public init(code: String = "", codeVerifier: String? = nil) {
        self.code = code
        self.codeVerifier = codeVerifier
    }
}
