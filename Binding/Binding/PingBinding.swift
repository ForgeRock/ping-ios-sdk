/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingJourney
import UIKit

/// Main class for handling device binding and signing.
public class PingBinder {
    
    /// Binds a device to a user account.
    /// - Parameters:
    ///   - callback: The `DeviceBindingCallback` object that contains the necessary information for binding.
    ///   - config: A closure to configure the `DeviceBindingConfig`.
    /// - Returns: The JWS signed with the new key.
    public static func bind(callback: DeviceBindingCallback, config: (DeviceBindingConfig) -> Void = { _ in }) async throws -> String {
        let deviceBindingConfig = DeviceBindingConfig()
        config(deviceBindingConfig)
        
        let deviceAuthenticator = deviceBindingConfig.authenticator(type: callback.deviceBindingAuthenticationType, prompt: Prompt(title: callback.title, subtitle: callback.subtitle, description: callback.description))
        let userKeyStorage = deviceBindingConfig.keyStorage()
        
        if !deviceAuthenticator.isSupported(attestation: callback.attestation) {
            throw DeviceBindingError.deviceNotSupported
        }
        
        try await clearKeys(deviceAuthenticator: deviceAuthenticator, userKeyStorage: userKeyStorage, userId: callback.userId)
        
        let keyPair = try await deviceAuthenticator.register(attestation: callback.attestation)
        _ = try await deviceAuthenticator.authenticate()
        
        let userKey = UserKey(keyTag: keyPair.keyTag, userId: callback.userId, username: callback.userName, kid: UUID().uuidString, authType: callback.deviceBindingAuthenticationType)
        try userKeyStorage.save(userKey: userKey)
        
        let signingParams = SigningParameters(algorithm: deviceBindingConfig.signingAlgorithm,
                                            keyPair: keyPair,
                                            kid: userKey.kid,
                                            userId: callback.userId,
                                            challenge: callback.challenge,
                                            issueTime: deviceBindingConfig.issueTime(),
                                            notBeforeTime: deviceBindingConfig.notBeforeTime(),
                                            expiration: deviceBindingConfig.expirationTime(callback.timeout),
                                            attestation: callback.attestation)
        
        let jws = try deviceAuthenticator.sign(params: signingParams)
        callback.setJws(jws)
        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            callback.setDeviceId(deviceId)
        }
        callback.setDeviceName(deviceBindingConfig.deviceName)
        
        return jws
    }
    
    /// Signs a challenge with a previously bound device.
    /// - Parameters:
    ///   - callback: The `DeviceSigningVerifierCallback` object that contains the necessary information for signing.
    ///   - config: A closure to configure the `DeviceBindingConfig`.
    /// - Returns: The JWS signed with the device key.
    public static func sign(callback: DeviceSigningVerifierCallback, config: (DeviceBindingConfig) -> Void = { _ in }) async throws -> String {
        let deviceBindingConfig = DeviceBindingConfig()
        config(deviceBindingConfig)
        
        let claims = deviceBindingConfig.claims
        try validate(customClaims: claims)
        
        let storage = deviceBindingConfig.keyStorage()
        
        let userKey: UserKey
        if let userId = callback.userId {
            guard let key = try storage.findByUserId(userId) else {
                throw DeviceBindingError.deviceNotRegistered
            }
            userKey = key
        } else {
            let keys = try storage.findAll()
            if keys.isEmpty {
                throw DeviceBindingError.deviceNotRegistered
            } else if keys.count == 1,
                      let firstKey = keys.first {
                userKey = firstKey
            } else {
                if let selectedKey = deviceBindingConfig.userKeySelector(keys) {
                    userKey = selectedKey
                } else {
                    throw DeviceBindingError.deviceNotRegistered
                }
            }
        }
        
        let deviceAuthenticator = deviceBindingConfig.authenticator(type: userKey.authType, prompt: Prompt(title: callback.title, subtitle: callback.subtitle, description: callback.description))
        
        let privateKey = try await deviceAuthenticator.authenticate()
        
        let signingParams = UserKeySigningParameters(algorithm: deviceBindingConfig.signingAlgorithm,
                                                   userKey: userKey,
                                                   privateKey: privateKey,
                                                   challenge: callback.challenge,
                                                   issueTime: deviceBindingConfig.issueTime(),
                                                   notBeforeTime: deviceBindingConfig.notBeforeTime(),
                                                   expiration: deviceBindingConfig.expirationTime(callback.timeout),
                                                   customClaims: claims)
        
        let jws = try deviceAuthenticator.sign(params: signingParams)
        callback.setJws(jws)
        
        return jws
    }
    
    /// Clears the keys for a given user.
    /// - Parameters:
    ///   - deviceAuthenticator: The `DeviceAuthenticator` to use.
    ///   - userKeyStorage: The `UserKeysStorage` to use.
    ///   - userId: The user ID.
    private static func clearKeys(deviceAuthenticator: DeviceAuthenticator, userKeyStorage: UserKeysStorage, userId: String) async throws {
        try await deviceAuthenticator.deleteKeys()
        try userKeyStorage.deleteByUserId(userId)
    }
    
    /// Validates the custom claims.
    /// - Parameter customClaims: The custom claims to validate.
    private static func validate(customClaims: [String: Any]) throws {
        let reservedKeys = [Constants.sub, Constants.exp, Constants.iat, Constants.nbf, Constants.iss, Constants.challenge]
        for key in customClaims.keys {
            if reservedKeys.contains(key) {
                throw DeviceBindingError.invalidClaim
            }
        }
    }
    
}