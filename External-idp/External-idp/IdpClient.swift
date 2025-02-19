//
//  IdpClient.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents the IdpClient struct. The IdpClient struct represents the client configuration for the IDP.
/// - property clientId: The client ID.
/// - property redirectUri: The redirect URI.
/// - property scopes: The scopes.
/// - property nonce: The nonce.
/// - property continueUrl: The continue URL.
///
public struct IdpClient {
    public var clientId: String? = nil
    public var redirectUri: String? = nil
    public var scopes: [String] = []
    public var nonce: String? = nil
    public var continueUrl: String? = nil
}
