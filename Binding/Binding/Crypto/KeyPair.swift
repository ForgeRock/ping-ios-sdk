
//
//  KeyPair.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A struct representing a cryptographic key pair, containing a public and a private key.
public struct KeyPair {
    /// The public key component of the key pair.
    public let publicKey: SecKey
    /// The private key component of the key pair.
    public let privateKey: SecKey
    /// The tag that uniquely identifies the key pair in the Keychain.
    public let keyTag: String
}
