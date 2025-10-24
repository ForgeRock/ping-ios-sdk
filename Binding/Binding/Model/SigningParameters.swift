
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// A struct representing the parameters for signing a JWT.
struct SigningParameters {
    let algorithm: String
    let keyPair: KeyPair
    let kid: String
    let userId: String
    let challenge: String
    let issueTime: Date
    let notBeforeTime: Date
    let expiration: Date
    let attestation: Attestation
}
