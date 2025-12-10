
//
//  DeviceAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingCommons
import PingJourneyPlugin

/// A protocol defining the capabilities and requirements for any device authenticator.
/// Authenticators conforming to this protocol are responsible for key management (generation, authentication, deletion)
/// and JWT signing operations specific to their authentication type (e.g., biometrics, PIN).
public protocol DeviceAuthenticator {
    /// An optional `Journey` object providing context for the authentication flow.
    var journey: Journey? { get set }
    
    /// Generates a new public and private key pair for the authenticator.
    /// - Throws: `KeyPairGenerationError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    func register() async throws -> KeyPair
    
    /// - Returns: A `Result` containing the `SecKey` on success, or an `Error` on failure.
    func authenticate(keyTag: String) async -> Result<SecKey, Error>
    
    /// Checks if the authenticator is supported on the current device.
    /// - Parameter attestation: The attestation type to consider for support.
    /// - Returns: `true` if the authenticator is supported, `false` otherwise.
    func isSupported(attestation: Attestation) -> Bool
    
    /// Returns the specific type of device binding authentication this authenticator handles.
    func type() -> DeviceBindingAuthenticationType
    
    /// Provides the access control settings for the authenticator's keys.
    /// - Returns: A `SecAccessControl` object defining key access policies, or `nil` if not applicable.
    func accessControl() -> SecAccessControl?
    
    /// Sets the prompt information to be displayed to the user during authentication.
    /// - Parameter prompt: A `Prompt` struct containing title, subtitle, and description.
    func setPrompt(_ prompt: Prompt)
    
    /// Initializes the authenticator with a user ID and prompt.
    /// - Parameters:
    ///   - userId: The ID of the user associated with the authenticator.
    ///   - prompt: The prompt to display to the user.
    func initialize(userId: String, prompt: Prompt)
    
    /// Initializes the authenticator with a user ID.
    /// - Parameter userId: The ID of the user associated with the authenticator.
    func initialize(userId: String)
    
    /// Deletes all keys associated with this authenticator.
    /// - Throws: `KeyDeletionError` if key deletion fails.
    func deleteKeys() async throws
    
    /// Returns the issue time for a token, typically the current date.
    /// - Returns: A `Date` object representing the issue time.
    func issueTime() -> Date
    
    /// Returns the not-before time for a token, typically the current date.
    /// - Returns: A `Date` object representing the not-before time.
    func notBeforeTime() -> Date
    
    /// Validates custom claims against a list of reserved JWT claim names.
    /// - Parameter customClaims: A dictionary of custom claims to be validated.
    /// - Returns: `true` if no custom claims conflict with reserved names, `false` otherwise.
    func validateCustomClaims(_ customClaims: [String: Any]) -> Bool
    
    /// Signs the given parameters to generate a JWS (JSON Web Signature).
    /// This method is used for initial device binding where a new key pair is generated.
    /// - Parameters:
    ///   - params: The `SigningParameters` containing all necessary data for signing.
    ///   - journey: An optional `Journey` object for context, used to derive the issuer.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails.
    func sign(params: SigningParameters, journey: Journey?) throws -> String
    
    /// Signs the given parameters to generate a JWS (JSON Web Signature).
    /// This method is used for subsequent signing operations with an already bound user key.
    /// - Parameters:
    ///   - params: The `UserKeySigningParameters` containing all necessary data for signing.
    ///   - journey: An optional `Journey` object for context, used to derive the issuer.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails.
    func sign(params: UserKeySigningParameters, journey: Journey?) throws -> String
}

public extension DeviceAuthenticator {
    /// Default implementation for a signing method that generates a JWS.
    /// This constructs the JWT payload with standard claims and signs it using the provided key pair.
    /// - Parameters:
    ///   - params: The `SigningParameters` containing data like challenge, expiration, user ID, and key pair.
    ///   - journey: An optional `Journey` object to provide context for the issuer claim.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails or `SecKeyToJWKError` if JWK conversion fails.
    func sign(params: SigningParameters, journey: Journey?) throws -> String {
        // Initialize claims dictionary with standard JWT claims
        var claims: [String: Any] = [
            Constants.challenge: params.challenge,
            Constants.exp: Int(params.expiration.timeIntervalSince1970),
            Constants.iat: Int(params.issueTime.timeIntervalSince1970),
            Constants.nbf: Int(params.notBeforeTime.timeIntervalSince1970),
            Constants.sub: params.userId,
            Constants.platform: Constants.ios
        ]
        
        // Add iss claim using the bundle identifier
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            claims[Constants.iss] = bundleIdentifier
        }
        
        // Sign the JWT using CompactJwt utility
        return try CompactJwt.sign(claims: claims, privateKey: params.keyPair.privateKey, publicKey: params.keyPair.publicKey, algorithm: .ecdsaSignatureMessageX962SHA256, kid: params.kid)
    }
    
    
    /// Signs the given parameters with an existing user key to generate a JWS.
    /// This constructs the JWT payload with standard and custom claims and signs it using the provided keys.
    /// - Parameters:
    ///   - params: The `UserKeySigningParameters` containing data like challenge, expiration, user key, and private/public keys.
    ///   - journey: An optional `Journey` object to provide context for the issuer claim.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails or `SecKeyToJWKError` if JWK conversion fails.
    func sign(params: UserKeySigningParameters, journey: Journey?) throws -> String {
        // Initialize claims dictionary with standard JWT claims
        var claims: [String: Any] = [
            Constants.challenge: params.challenge,
            Constants.exp: Int(params.expiration.timeIntervalSince1970),
            Constants.iat: Int(params.issueTime.timeIntervalSince1970),
            Constants.nbf: Int(params.notBeforeTime.timeIntervalSince1970),
            Constants.sub: params.userKey.userId,
            Constants.platform: Constants.ios
        ]
        
        // Add custom claims from parameters
        for (key, value) in params.customClaims {
            claims[key] = value
        }
        
        // Add iss claim using the bundle identifier
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            claims[Constants.iss] = bundleIdentifier
        }
        
        // Sign the JWT using CompactJwt utility
        return try CompactJwt.sign(claims: claims, privateKey: params.privateKey, publicKey: params.publicKey, algorithm: .ecdsaSignatureMessageX962SHA256, kid: params.userKey.kid)
    }
}

