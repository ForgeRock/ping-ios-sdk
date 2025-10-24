
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingMfaCommons

/// A protocol for device authenticators.
protocol DeviceAuthenticator {
    /// The type of device binding authentication.
    var type: DeviceBindingAuthenticationType { get }
    
    /// Registers a new key pair.
    ///
    /// - Parameter attestation: The attestation type.
    /// - Returns: The generated key pair.
    func register(attestation: Attestation) async throws -> KeyPair
    
    /// Authenticates the user.
    ///
    /// - Returns: The private key.
    func authenticate() async throws -> SecKey
    
    /// Checks if the authenticator is supported.
    ///
    /// - Parameter attestation: The attestation type.
    /// - Returns: A boolean indicating whether the authenticator is supported.
    func isSupported(attestation: Attestation) -> Bool
    
    /// Deletes the keys.
    func deleteKeys() async throws
    
    /// Signs a JWT.
    ///
    /// - Parameter params: The signing parameters.
    /// - Returns: The signed JWT.
    func sign(params: SigningParameters) throws -> String
    
    /// Signs a JWT.
    ///
    /// - Parameter params: The user key signing parameters.
    /// - Returns: The signed JWT.
    func sign(params: UserKeySigningParameters) throws -> String
}

extension DeviceAuthenticator {
    func sign(params: SigningParameters) throws -> String {
        let claims: [String: Any] = [
            Constants.sub: params.userId,
            Constants.iss: Bundle.main.bundleIdentifier ?? "",
            Constants.exp: params.expiration,
            Constants.iat: params.issueTime,
            Constants.nbf: params.notBeforeTime,
            Constants.challenge: params.challenge,
            Constants.platform: "ios"
        ]
        return try CompactJwt.signJwtClaims(base64Secret: "", claims: claims)
    }
    
    func sign(params: UserKeySigningParameters) throws -> String {
        var claims: [String: Any] = [
            Constants.sub: params.userKey.userId,
            Constants.iss: Bundle.main.bundleIdentifier ?? "",
            Constants.exp: params.expiration,
            Constants.iat: params.issueTime,
            Constants.nbf: params.notBeforeTime,
            Constants.challenge: params.challenge,
            Constants.platform: "ios"
        ]
        claims.merge(params.customClaims) { (current, _) in current }
        return try CompactJwt.signJwtClaims(base64Secret: "", claims: claims)
    }
}
