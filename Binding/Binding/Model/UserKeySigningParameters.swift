
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
    let algorithm: String
    /// The user key to use for signing.
    let userKey: UserKey
    /// The private key to use for signing.
    let privateKey: SecKey
    /// The public key to use for signing.
    let publicKey: SecKey
    /// The challenge to sign.
    let challenge: String
    /// The issue time of the JWT.
    let issueTime: Date
    /// The not-before time of the JWT.
    let notBeforeTime: Date
    /// The expiration time of the JWT.
    let expiration: Date
    /// The custom claims to include in the JWT.
    let customClaims: [String: Any]
}

