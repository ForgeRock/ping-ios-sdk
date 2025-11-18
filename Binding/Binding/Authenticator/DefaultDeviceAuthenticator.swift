
//
//  DefaultDeviceAuthenticator.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
import Security
import PingMfaCommons

/// A base class for device authenticators, providing default implementations for the `DeviceAuthenticator` protocol.
/// Subclasses should override methods to provide specific authentication logic.
open class DefaultDeviceAuthenticator: DeviceAuthenticator {
    
    /// The optional `Journey` object providing context for the authentication flow.
    public var journey: Journey?
    
    /// An optional `Prompt` object containing information to display to the user during authentication.
    public var prompt: Prompt?
    
    /// Returns the specific type of device binding authentication this authenticator handles.
    /// Default implementation returns `.none`. Subclasses should override this.
    open func type() -> DeviceBindingAuthenticationType {
        return .none
    }
    
    /// Generates a new public and private key pair for the authenticator.
    /// Default implementation throws `DeviceBindingStatus.unsupported`, requiring subclasses to provide concrete implementation.
    /// - Throws: `DeviceBindingStatus.unsupported` if not overridden by a subclass.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    open func register() async throws -> KeyPair {
         throw DeviceBindingStatus.unsupported(errorMessage: "Cannot use DefaultDeviceAuthenticator. Must be subclassed")
    }
    
    /// - Returns: A `Result` containing the `SecKey` on success, or an `Error` on failure.
    open func authenticate(keyTag: String) async -> Result<SecKey, Error> {
        return .failure(DeviceBindingError.unknown) // Should be implemented by subclasses
    }
    
    /// Checks if the authenticator is supported on the current device.
    /// Default implementation returns `false`. Subclasses should override this.
    /// - Parameter attestation: The attestation type to consider for support.
    /// - Returns: `true` if the authenticator is supported, `false` otherwise.
    open func isSupported(attestation: Attestation) -> Bool {
        return false
    }
    
    /// Provides the access control settings for the authenticator's keys.
    /// Default implementation returns `nil`. Subclasses should override this to provide specific access control.
    /// - Returns: A `SecAccessControl` object defining key access policies, or `nil` if not applicable.
    open func accessControl() -> SecAccessControl? {
        return nil
    }
    
    /// Deletes all keys associated with this authenticator.
    /// Default implementation does nothing. Subclasses should override this to provide specific key deletion logic.
    /// - Throws: `KeyDeletionError` if key deletion fails.
    open func deleteKeys() async throws { }
    
    
    /// Default implementation for a signing method that generates a JWS.
    /// This constructs the JWT payload with standard claims and signs it using the provided key pair.
    /// - Parameters:
    ///   - params: The `SigningParameters` containing data like challenge, expiration, user ID, and key pair.
    ///   - journey: An optional `Journey` object to provide context for the issuer claim.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails or `SecKeyToJWKError` if JWK conversion fails.
    open func sign(params: SigningParameters, journey: Journey?) throws -> String {
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
        return try CompactJwt.sign(claims: claims, privateKey: params.keyPair.privateKey, publicKey: params.keyPair.publicKey, algorithm: params.algorithm, kid: params.kid)
    }
    
    
    /// Signs the given parameters with an existing user key to generate a JWS.
    /// This constructs the JWT payload with standard and custom claims and signs it using the provided keys.
    /// - Parameters:
    ///   - params: The `UserKeySigningParameters` containing data like challenge, expiration, user key, and private/public keys.
    ///   - journey: An optional `Journey` object to provide context for the issuer claim.
    /// - Returns: The compact serialized JWS string.
    /// - Throws: `JwtError` if JWT signing fails or `SecKeyToJWKError` if JWK conversion fails.
    open func sign(params: UserKeySigningParameters, journey: Journey?) throws -> String {
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
        return try CompactJwt.sign(claims: claims, privateKey: params.privateKey, publicKey: params.publicKey, algorithm: params.algorithm, kid: params.userKey.kid)
    }
    
    
    
    /// Sets the prompt information to be displayed to the user during authentication.
    /// - Parameter prompt: A `Prompt` struct containing title, subtitle, and description.
    open func setPrompt(_ prompt: Prompt) {
        self.prompt = prompt
    }
    
    
    /// Initializes the authenticator with a user ID and prompt.
    /// Calls `setPrompt` and then `initialize(userId:)`.
    /// - Parameters:
    ///   - userId: The ID of the user associated with the authenticator.
    ///   - prompt: The prompt to display to the user.
    open func initialize(userId: String, prompt: Prompt) {
        
        setPrompt(prompt)
        initialize(userId: userId)
    }
    
    
    /// Initializes the authenticator with a user ID.
    /// Default implementation does nothing. Subclasses can override this for specific initialization logic.
    /// - Parameter userId: The ID of the user associated with the authenticator.
    open func initialize(userId: String) {
        // No-op for default, subclasses can override
    }
    
    
    /// Returns the issue time for a token, typically the current date.
    /// - Returns: A `Date` object representing the issue time.
    open func issueTime() -> Date {
        return Date()
    }

    
    /// Returns the not-before time for a token, typically the current date.
    /// - Returns: A `Date` object representing the not-before time.
    open func notBeforeTime() -> Date {
        return Date()
    }
    
    /// Validates custom claims against a list of reserved JWT claim names.
    /// This prevents custom claims from overwriting standard JWT claims.
    ///
    /// - Parameter customClaims: A dictionary of custom claims to be validated.
    /// - Returns: `true` if no custom claims conflict with reserved names, `false` otherwise.
    /// - Throws: `DeviceBindingError.invalidClaim` if any custom claim is a reserved JWT claim.
    open func validateCustomClaims(_ customClaims: [String: Any]) -> Bool {
        // Define reserved JWT claim names
        let reservedKeys = [Constants.sub,
                              Constants.challenge,
                              Constants.exp,
                              Constants.iat,
                              Constants.nbf,
                              Constants.iss]
        // Check if any custom claim key is a reserved key
        return customClaims.keys.filter { reservedKeys.contains($0) }.isEmpty
    }
}

