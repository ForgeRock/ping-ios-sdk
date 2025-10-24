
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// A struct representing the parameters for signing a JWT with a user key.
struct UserKeySigningParameters {
    let algorithm: String
    let userKey: UserKey
    let privateKey: SecKey
    let challenge: String
    let issueTime: Date
    let notBeforeTime: Date
    let expiration: Date
    let customClaims: [String: Any]
}
