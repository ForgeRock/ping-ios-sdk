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
    /// - Returns: `true` if the authenticator is supported, `false` otherwise.
    func isSupported(attestation: Attestation) -> Bool
    
    /// Signs the given parameters with the key.
    ///
    /// - Parameter params: The parameters to sign.
    /// - Returns: The JWS.
    func sign(params: SigningParameters) throws -> String
    
    /// Signs the given parameters with the key.
    ///
    /// - Parameter params: The parameters to sign.
    /// - Returns: The JWS.
    func sign(params: UserKeySigningParameters) throws -> String
    
    /// Deletes all keys associated with this authenticator.
    func deleteKeys() async throws
}

extension DeviceAuthenticator {
    func sign(params: SigningParameters) throws -> String {
        let claims = ["challenge": params.challenge]
        return try CompactJwt.sign(claims: claims, privateKey: params.keyPair.privateKey, algorithm: .ecdsaSignatureMessageX962SHA256, kid: params.kid)
    }
    
    func sign(params: UserKeySigningParameters) throws -> String {
        let claims = ["challenge": params.challenge]
        return try CompactJwt.sign(claims: claims, privateKey: params.privateKey, algorithm: .ecdsaSignatureMessageX962SHA256, kid: params.userKey.kid)
    }
}
