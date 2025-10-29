
//
//  SigningParameters.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A struct representing the parameters for signing a JWS during a device binding operation.
public struct SigningParameters {
    /// The signing algorithm.
    let algorithm: String
    /// The key pair to use for signing.
    let keyPair: KeyPair
    /// The key ID.
    let kid: String
    /// The user ID.
    let userId: String
    /// The challenge to sign.
    let challenge: String
    /// The issue time of the JWT.
    let issueTime: Date
    /// The not-before time of the JWT.
    let notBeforeTime: Date
    /// The expiration time of the JWT.
    let expiration: Date
    /// The attestation to include in the JWT.
    let attestation: Attestation
}

