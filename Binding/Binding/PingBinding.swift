//
//  PingBinding.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
#if canImport(UIKit)
import UIKit
#endif

/// Main class for handling device binding and signing.
class Binding {
    
    /// Binds a device to a user account.
    ///
    /// This method performs the following steps:
    /// 1. Configures the device binding settings.
    /// 2. Checks if the device supports the required attestation format.
    /// 3. Clears any existing keys for the user.
    /// 4. Generates a new key pair and authenticates the user.
    /// 5. Stores the new user key.
    /// 6. Creates and signs a JWS with the new key.
    /// 7. Sets the JWS, device ID, and device name on the callback.
    ///
    /// - Parameters:
    ///   - callback: The `DeviceBindingCallback` object that contains the necessary information for binding.
    ///   - journey: The `Journey` object associated with the current authentication flow.
    ///   - config: A closure to configure the `DeviceBindingConfig`.
    /// - Returns: The JWS signed with the new key.
    /// - Throws: A `DeviceBindingError` if the device is not supported, or if any other error occurs during the binding process.
    static func bind(callback: DeviceBindingCallback, journey: Journey?, config: (DeviceBindingConfig) -> Void = { _ in }) async throws -> String {
        let deviceBindingConfig = DeviceBindingConfig()
        config(deviceBindingConfig)
        
        // Check for and migrate legacy data if present
        _ = await BindingMigration.migrateIfNeeded()
        
        var deviceAuthenticator = deviceBindingConfig.authenticator(type: callback.deviceBindingAuthenticationType, prompt: Prompt(title: callback.title, subtitle: callback.subtitle, description: callback.description))
        deviceAuthenticator.journey = callback.journey
        let userKeyStorage = deviceBindingConfig.keyStorage()
        
        // Check if the device supports the required attestation format.
        if !deviceAuthenticator.isSupported(attestation: callback.attestation) {
            throw DeviceBindingError.deviceNotSupported
        }
        
        // Clear any existing keys for the user.
        try await Binding.clearKeys(deviceAuthenticator: deviceAuthenticator, userKeyStorage: userKeyStorage, userId: callback.userId)
        
        // Generate a new key pair and authenticate the user.
        let keyPair = try await deviceAuthenticator.register()
        let authResult = await deviceAuthenticator.authenticate(keyTag: keyPair.keyTag)
        
        switch authResult {
        case .success:
            // Store the new user key.
            let newUserKey = UserKey(keyTag: keyPair.keyTag, userId: callback.userId, username: callback.userName, kid: keyPair.keyTag, authType: callback.deviceBindingAuthenticationType)
            
            try await userKeyStorage.save(userKey: newUserKey)
        case .failure(let error):
            throw error
        }
        
        // Create and sign a JWS with the new key.
        let signingParams = SigningParameters(algorithm: deviceBindingConfig.getSecKeyAlgorithm(),
                                              keyPair: keyPair,
                                              kid: keyPair.keyTag,
                                              userId: callback.userId,
                                              challenge: callback.challenge,
                                              issueTime: deviceBindingConfig.issueTime(),
                                              notBeforeTime: deviceBindingConfig.notBeforeTime(),
                                              expiration: deviceBindingConfig.expirationTime(callback.timeout),
                                              attestation: callback.attestation)
        
        let jws = try deviceAuthenticator.sign(params: signingParams, journey: journey)
        
        // Set the JWS, device ID, and device name on the callback.
        callback.setJws(jws)
        #if canImport(UIKit)
        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            callback.setDeviceId(deviceId)
        }
        #endif
        callback.setDeviceName(deviceBindingConfig.deviceName)
        
        return jws
    }
    
    /// Signs a challenge with a previously bound device.
    ///
    /// This method performs the following steps:
    /// 1. Configures the device binding settings.
    /// 2. Validates any custom claims.
    /// 3. Retrieves the user key from storage.
    /// 4. Authenticates the user.
    /// 5. Creates and signs a JWS with the user's key.
    /// 6. Sets the JWS on the callback.
    ///
    /// - Parameters:
    ///   - callback: The `DeviceSigningVerifierCallback` object that contains the necessary information for signing.
    ///   - journey: The `Journey` object associated with the current authentication flow.
    ///   - config: A closure to configure the `DeviceBindingConfig`.
    /// - Returns: The JWS signed with the device key.
    /// - Throws: A `DeviceBindingError` if the device is not registered, or if any other error occurs during the signing process.
    static func sign(callback: DeviceSigningVerifierCallback, journey: Journey?, config: (DeviceBindingConfig) -> Void = { _ in }) async throws -> String {
        let deviceBindingConfig = DeviceBindingConfig()
        config(deviceBindingConfig)
        
        let claims = deviceBindingConfig.claims
        try validate(customClaims: claims)
        
        let storage = deviceBindingConfig.keyStorage()
        
        // Check for and migrate legacy data if present
        // This ensures legacy keys are available for signing
        _ = await BindingMigration.migrateIfNeeded()
        
        // Retrieve the user key from storage.
        let retrievedUserKey: UserKey
        if let userId = callback.userId, !userId.isEmpty {
            guard let key = try await storage.findByUserId(userId) else {
                throw DeviceBindingError.deviceNotRegistered
            }
            retrievedUserKey = key
        } else {
            let keys = try await storage.findAll()
            if keys.isEmpty {
                throw DeviceBindingError.deviceNotRegistered
            } else if keys.count == 1,
                      let firstKey = keys.first {
                retrievedUserKey = firstKey
            } else {
                // Multiple keys available - use the selector to choose
                #if canImport(UIKit)
                let prompt = Prompt(title: callback.title, subtitle: callback.subtitle, description: callback.description)
                guard let selectedKey = await deviceBindingConfig.userKeySelector.selectKey(userKeys: keys, prompt: prompt) else {
                    throw DeviceBindingError.userCanceled
                }
                retrievedUserKey = selectedKey
                #else
                // On non-UIKit platforms, default to first key
                guard let firstKey = keys.first else {
                    throw DeviceBindingError.deviceNotRegistered
                }
                retrievedUserKey = firstKey
                #endif
            }
        }
        
        var deviceAuthenticator: DeviceAuthenticator
        if let customAuthenticator = deviceBindingConfig.deviceAuthenticator {
            deviceAuthenticator = customAuthenticator
        } else {
            deviceAuthenticator = deviceBindingConfig.authenticator(type: retrievedUserKey.authType, prompt: Prompt(title: callback.title, subtitle: callback.subtitle, description: callback.description))
        }
        
        deviceAuthenticator.journey = callback.journey
        
        // Authenticate the user.
        let authResult = await deviceAuthenticator.authenticate(keyTag: retrievedUserKey.keyTag)
        
        let privateKey: SecKey
        switch authResult {
        case .success(let key):
            privateKey = key
        case .failure(let error):
            throw error
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw DeviceBindingError.unknown
        }
        
        // Create and sign a JWS with the user's key.
        let signingParams = UserKeySigningParameters(algorithm: deviceBindingConfig.getSecKeyAlgorithm(),
                                                     userKey: retrievedUserKey,
                                                     privateKey: privateKey,
                                                     publicKey: publicKey,
                                                     challenge: callback.challenge,
                                                     issueTime: deviceBindingConfig.issueTime(),
                                                     notBeforeTime: deviceBindingConfig.notBeforeTime(),
                                                     expiration: deviceBindingConfig.expirationTime(callback.timeout),
                                                     customClaims: claims)
        
        let jws = try deviceAuthenticator.sign(params: signingParams, journey: journey)
        
        // Set the JWS on the callback.
        callback.setJws(jws)
        
        return jws
    }
    
    /// Clears the keys for a given user.
    /// - Parameters:
    ///   - deviceAuthenticator: The `DeviceAuthenticator` to use.
    ///   - userKeyStorage: The `UserKeysStorage` to use.
    ///   - userId: The user ID.
    static func clearKeys(deviceAuthenticator: DeviceAuthenticator, userKeyStorage: UserKeysStorage, userId: String) async throws {
        try await userKeyStorage.deleteByUserId(userId)
    }
    
    /// Validates the custom claims.
    ///
    /// This method checks that the custom claims do not contain any reserved keys.
    ///
    /// - Parameter customClaims: The custom claims to validate.
    /// - Throws: A `DeviceBindingError.invalidClaim` if a reserved key is found in the custom claims.
    static func validate(customClaims: [String: Any]) throws {
        let reservedKeys = [Constants.sub, Constants.exp, Constants.iat, Constants.nbf, Constants.iss, Constants.challenge]
        for key in customClaims.keys {
            if reservedKeys.contains(key) {
                throw DeviceBindingError.invalidClaim
            }
        }
    }
}

