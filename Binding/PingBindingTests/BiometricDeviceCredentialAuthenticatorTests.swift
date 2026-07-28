//
//  BiometricDeviceCredentialAuthenticatorTests.swift
//  PingBinding
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import LocalAuthentication
@testable import PingBinding
import PingStorage
import PingJourneyPlugin
import PingOrchestrate

// MARK: - Testable Subclass

/// A testable subclass that allows injecting a fake biometric domain state
/// without requiring real LAContext / Secure Enclave hardware.
class TestBiometricDeviceCredentialAuthenticator: BiometricDeviceCredentialAuthenticator {
    var fakeBiometricDomainState: Data?
    
    override func biometricDomainState() -> Data? {
        return fakeBiometricDomainState
    }
}

// MARK: - Tests

final class BiometricDeviceCredentialAuthenticatorTests: XCTestCase {
    
    // MARK: - UserKey biometricDomainState Tests
    
    func testUserKey_WithBiometricDomainState() {
        // Given
        let state = Data([0x01, 0x02, 0x03])
        
        // When
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: state)
        
        // Then
        XCTAssertEqual(userKey.biometricDomainState, state)
        XCTAssertEqual(userKey.authType, .biometricAllowFallback)
    }
    
    func testUserKey_WithoutBiometricDomainState_DefaultsToNil() {
        // When
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback)
        
        // Then
        XCTAssertNil(userKey.biometricDomainState)
    }
    
    func testUserKey_CodableRoundTrip_WithBiometricDomainState() throws {
        // Given
        let state = Data([0xAA, 0xBB, 0xCC])
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: state)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(userKey)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserKey.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.biometricDomainState, state)
        XCTAssertEqual(decoded.keyTag, "tag1")
        XCTAssertEqual(decoded.userId, "user1")
        XCTAssertEqual(decoded.authType, .biometricAllowFallback)
    }
    
    func testUserKey_CodableRoundTrip_WithNilBiometricDomainState() throws {
        // Given
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(userKey)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserKey.self, from: data)
        
        // Then
        XCTAssertNil(decoded.biometricDomainState)
    }
    
    func testUserKey_DecodesLegacyJSON_WithoutBiometricDomainState() throws {
        // Given - JSON without biometricDomainState field, simulating a key stored before the update
        let legacyJSON = """
        {
            "keyTag": "legacyTag",
            "userId": "legacyUser",
            "username": "Legacy User",
            "kid": "legacyKid",
            "authType": "BIOMETRIC_ALLOW_FALLBACK",
            "createdAt": 725846400
        }
        """.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserKey.self, from: legacyJSON)
        
        // Then - biometricDomainState should default to nil, not crash
        XCTAssertNil(decoded.biometricDomainState)
        XCTAssertEqual(decoded.keyTag, "legacyTag")
        XCTAssertEqual(decoded.userId, "legacyUser")
        XCTAssertEqual(decoded.authType, .biometricAllowFallback)
    }
    
    // MARK: - Sign with Biometric Domain State Validation Tests
    
    func testSign_SkipsValidation_WhenStoredStateIsNil() throws {
        // Given - A UserKey without biometricDomainState (pre-update key)
        let authenticator = TestBiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        authenticator.fakeBiometricDomainState = Data([0x01, 0x02]) // Current state is non-nil
        
        // Create a mock key pair for signing
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("Failed to create test key pair")
            return
        }
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback)
        // biometricDomainState is nil
        
        let params = UserKeySigningParameters(
            algorithm: .ecdsaSignatureMessageX962SHA256,
            userKey: userKey,
            privateKey: privateKey,
            publicKey: publicKey,
            challenge: "testChallenge",
            issueTime: Date(),
            notBeforeTime: Date(),
            expiration: Date().addingTimeInterval(300),
            customClaims: [:]
        )
        
        // When / Then - Should NOT throw, since stored state is nil (legacy key)
        XCTAssertNoThrow(try authenticator.sign(params: params, journey: nil))
    }
    
    func testSign_Succeeds_WhenBiometricStateUnchanged() throws {
        // Given - Stored and current state are the same
        let state = Data([0x01, 0x02, 0x03])
        let authenticator = TestBiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        authenticator.fakeBiometricDomainState = state
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("Failed to create test key pair")
            return
        }
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: state)
        
        let params = UserKeySigningParameters(
            algorithm: .ecdsaSignatureMessageX962SHA256,
            userKey: userKey,
            privateKey: privateKey,
            publicKey: publicKey,
            challenge: "testChallenge",
            issueTime: Date(),
            notBeforeTime: Date(),
            expiration: Date().addingTimeInterval(300),
            customClaims: [:]
        )
        
        // When / Then - Should succeed since state hasn't changed
        XCTAssertNoThrow(try authenticator.sign(params: params, journey: nil))
    }
    
    func testSign_ThrowsDeviceNotRegistered_WhenBiometricStateChanged() throws {
        // Given - Stored state differs from current state (biometric enrollment changed)
        let storedState = Data([0x01, 0x02, 0x03])
        let currentState = Data([0x04, 0x05, 0x06])
        
        let authenticator = TestBiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        authenticator.fakeBiometricDomainState = currentState
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("Failed to create test key pair")
            return
        }
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: storedState)
        
        let params = UserKeySigningParameters(
            algorithm: .ecdsaSignatureMessageX962SHA256,
            userKey: userKey,
            privateKey: privateKey,
            publicKey: publicKey,
            challenge: "testChallenge",
            issueTime: Date(),
            notBeforeTime: Date(),
            expiration: Date().addingTimeInterval(300),
            customClaims: [:]
        )
        
        // When / Then - Should throw deviceNotRegistered
        do {
            _ = try authenticator.sign(params: params, journey: nil)
            XCTFail("Sign should have thrown deviceNotRegistered when biometric state changed")
        } catch let error as DeviceBindingError {
            XCTAssertEqual(error, .deviceNotRegistered)
        } catch {
            XCTFail("Expected DeviceBindingError.deviceNotRegistered but got: \(error)")
        }
    }
    
    func testSign_ThrowsDeviceNotRegistered_WhenBiometricsRemoved() throws {
        // Given - Biometrics were enrolled at bind time but have been removed since
        let storedState = Data([0x01, 0x02, 0x03])
        
        let authenticator = TestBiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        authenticator.fakeBiometricDomainState = nil // Biometrics no longer enrolled
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("Failed to create test key pair")
            return
        }
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: storedState)
        
        let params = UserKeySigningParameters(
            algorithm: .ecdsaSignatureMessageX962SHA256,
            userKey: userKey,
            privateKey: privateKey,
            publicKey: publicKey,
            challenge: "testChallenge",
            issueTime: Date(),
            notBeforeTime: Date(),
            expiration: Date().addingTimeInterval(300),
            customClaims: [:]
        )
        
        // When / Then - Should throw deviceNotRegistered since biometrics were removed
        do {
            _ = try authenticator.sign(params: params, journey: nil)
            XCTFail("Sign should have thrown deviceNotRegistered when biometrics were removed")
        } catch let error as DeviceBindingError {
            XCTAssertEqual(error, .deviceNotRegistered)
        } catch {
            XCTFail("Expected DeviceBindingError.deviceNotRegistered but got: \(error)")
        }
    }
    
    // MARK: - Authenticator Type Test
    
    func testType_ReturnsBiometricAllowFallback() {
        let authenticator = BiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        XCTAssertEqual(authenticator.type(), .biometricAllowFallback)
    }
    
    // MARK: - isSupported Tests
    
    func testIsSupported_ReturnsFalseOnSimulator() {
        let authenticator = BiometricDeviceCredentialAuthenticator(config: BiometricAuthenticatorConfig())
        #if targetEnvironment(simulator)
        XCTAssertFalse(authenticator.isSupported(attestation: .none))
        #else
        var error: NSError?
        let hasPasscode = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        if hasPasscode {
            XCTAssertTrue(authenticator.isSupported(attestation: .none))
        } else {
            XCTAssertFalse(authenticator.isSupported(attestation: .none))
        }
        #endif
    }
    
    // MARK: - UserKeysStorage with biometricDomainState Tests

    func testUserKeysStorage_PersistsBiometricDomainState() async throws {
        // Given
        let state = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let storage = KeychainStorage<[UserKey]>(account: "testBiometricStateKeys", encryptor: NoEncryptor())
        let config = UserKeyStorageConfig(storage: storage)
        let userKeyStorage = UserKeysStorage(config: config)
        
        // Clean up
        try? await userKeyStorage.deleteAll()
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .biometricAllowFallback, biometricDomainState: state)
        
        // When
        try await userKeyStorage.save(userKey: userKey)
        let retrieved = try await userKeyStorage.findByUserId("user1")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.biometricDomainState, state)
        
        // Clean up
        try await userKeyStorage.deleteAll()
    }
    
    func testUserKeysStorage_PersistsNilBiometricDomainState() async throws {
        // Given
        let storage = KeychainStorage<[UserKey]>(account: "testBiometricStateKeys", encryptor: NoEncryptor())
        let config = UserKeyStorageConfig(storage: storage)
        let userKeyStorage = UserKeysStorage(config: config)
        
        // Clean up
        try? await userKeyStorage.deleteAll()
        
        let userKey = UserKey(keyTag: "tag1", userId: "user1", username: "User 1", kid: "kid1", authType: .none)
        
        // When
        try await userKeyStorage.save(userKey: userKey)
        let retrieved = try await userKeyStorage.findByUserId("user1")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertNil(retrieved?.biometricDomainState)
        
        // Clean up
        try await userKeyStorage.deleteAll()
    }
}
