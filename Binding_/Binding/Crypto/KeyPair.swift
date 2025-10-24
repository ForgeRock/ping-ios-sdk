
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// A struct representing a cryptographic key pair.
public struct KeyPair {
    /// The public key.
    public let publicKey: SecKey
    /// The private key.
    public let privateKey: SecKey
    /// The key tag.
    public let keyTag: String
}
