
//
//  UserKeySigningParameters.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A struct representing the parameters for signing a JWS with a previously bound user key.
public struct UserKeySigningParameters {
    /// The signing algorithm.
    public let algorithm: String
    /// The user key to use for signing.
    public let userKey: UserKey
    /// The private key to use for signing.
    public let privateKey: SecKey
    /// The public key to use for signing.
    public let publicKey: SecKey
    /// The challenge to sign.
    public let challenge: String
    /// The issue time of the JWT.
    public let issueTime: Date
    /// The not-before time of the JWT.
    public let notBeforeTime: Date
    /// The expiration time of the JWT.
    public let expiration: Date
    /// The custom claims to include in the JWT.
    public let customClaims: [String: Any]
}

