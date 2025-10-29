
//
//  Attestation.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// An enum representing the type of attestation to be performed when generating a new key pair.
public enum Attestation {
    /// No attestation is performed.
    case none
    /// Attestation is performed with the given challenge.
    case challenge(String)
}
