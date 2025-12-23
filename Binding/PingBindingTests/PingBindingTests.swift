//
//  PingBindingTests.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBinding
@testable import PingJourneyPlugin

final class PingBindingTests: XCTestCase {
    
    var userKeyStorage: UserKeysStorage!
    
    override func setUp() async throws {
        try await super.setUp()
        let config = UserKeyStorageConfig()
        userKeyStorage = UserKeysStorage(config: config)
        
        // Clean up before each test
        try? await userKeyStorage.deleteByUserId("testUser")
        try? await userKeyStorage.deleteByUserId("testUser2")
    }
    
    override func tearDown() async throws {
        // Clean up after each test
        try? await userKeyStorage.deleteAll()
        userKeyStorage = nil
        
        try await super.tearDown()
    }
    
    // MARK: - PingBinder Tests
    
    func testBind_Success() async {
        // Given
        let callback = DeviceBindingCallback()
        callback.userId = "testUser"
        callback.userName = "Test User"
        callback.challenge = "challenge"
        callback.deviceBindingAuthenticationType = .none
        
        // When
        do {
            let jws = try await Binding.bind(callback: callback, journey: nil)
            
            // Then
            XCTAssertFalse(jws.isEmpty)
            
            let storedKey = try await userKeyStorage.findByUserId("testUser")
            XCTAssertNotNil(storedKey)
            XCTAssertEqual(storedKey?.userId, "testUser")
        } catch {
#if targetEnvironment(simulator)
            XCTAssertNotNil(error, "testBind_Success failed with error: \(error) - Expected failure on Simulators")
#else
            XCTFail("testBind_Success failed with unexpected error: \(error)")
#endif
        }
    }
    
    func testSign_Success() async {
        // Given: First, bind a device
        do {
            let bindCallback = DeviceBindingCallback()
            bindCallback.userId = "testUser"
            bindCallback.userName = "Test User"
            bindCallback.challenge = "challenge"
            bindCallback.deviceBindingAuthenticationType = .none
            _ = try await Binding.bind(callback: bindCallback, journey: nil)
            
            // Now, prepare for signing
            let signCallback = DeviceSigningVerifierCallback()
            signCallback.userId = "testUser"
            signCallback.challenge = "anotherChallenge"
            
            // When
            let jws = try await Binding.sign(callback: signCallback, journey: nil)
            
            // Then
            XCTAssertFalse(jws.isEmpty)
        } catch {
#if targetEnvironment(simulator)
            XCTAssertNotNil(error, "testBind_Success failed with error: \(error) - Expected failure on Simulators")
#else
            XCTFail("testBind_Success failed with unexpected error: \(error)")
#endif
        }
    }
    
    func testSign_FailsWhenNotRegistered() async {
        // Given
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "nonExistentUser"
        signCallback.challenge = "challenge"
        
        // When
        do {
            _ = try await Binding.sign(callback: signCallback, journey: nil)
            XCTFail("Signing should have failed because the device is not registered.")
        } catch {
            // Then
            guard let deviceBindingError = error as? DeviceBindingError else {
                XCTFail("Error was not a DeviceBindingError.")
                return
            }
            XCTAssertEqual(deviceBindingError, .deviceNotRegistered)
        }
    }
    
    func testBind_ClearsPreviousKeysForSameUser() async {
        do {
            // Given: Bind a user first
            let firstBindCallback = DeviceBindingCallback()
            firstBindCallback.userId = "testUser"
            firstBindCallback.userName = "Test User"
            firstBindCallback.challenge = "firstChallenge"
            _ = try await Binding.bind(callback: firstBindCallback, journey: nil)
            
            let firstKey = try await userKeyStorage.findByUserId("testUser")
            XCTAssertNotNil(firstKey, "First key should be stored.")
            
            // When: Bind the same user again
            let secondBindCallback = DeviceBindingCallback()
            secondBindCallback.userId = "testUser"
            secondBindCallback.userName = "Test User"
            secondBindCallback.challenge = "secondChallenge"
            _ = try await Binding.bind(callback: secondBindCallback, journey: nil)
            
            // Then
            let allKeys = try await userKeyStorage.findAll()
            let userKeys = allKeys.filter { $0.userId == "testUser" }
            
            XCTAssertEqual(userKeys.count, 1, "There should be only one key for the user.")
            let newKey = userKeys.first
            XCTAssertNotEqual(newKey?.keyTag, firstKey?.keyTag, "The new key should have a different keyTag.")
        } catch {
            #if targetEnvironment(simulator)
            XCTAssertNotNil(error, "testBind_ClearsPreviousKeysForSameUser failed with error: \(error) - Expected failure on Simulators")
            #else
            XCTFail("testBind_ClearsPreviousKeysForSameUser failed with unexpected error: \(error)")
            #endif
        }
    }
    
    // MARK: - UserKeysStorage Tests
    
    func testUserKeysStorage_SaveAndFindAll() async throws {
        // Given
        let userKey1 = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        let userKey2 = UserKey(keyTag: "tag2", userId: "testUser2", username: "Test User 2", kid: "kid2", authType: .none)
        
        // When
        try await userKeyStorage.save(userKey: userKey1)
        try await userKeyStorage.save(userKey: userKey2)
        
        // Then
        let allKeys = try await userKeyStorage.findAll()
        XCTAssertEqual(allKeys.count, 2)
        XCTAssertTrue(allKeys.contains(where: { $0.userId == "testUser" }))
        XCTAssertTrue(allKeys.contains(where: { $0.userId == "testUser2" }))
    }
    
    func testUserKeysStorage_FindByUserId() async throws {
        // Given
        let userKey = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        try await userKeyStorage.save(userKey: userKey)
        
        // When
        let foundKey = try await userKeyStorage.findByUserId("testUser")
        let notFoundKey = try await userKeyStorage.findByUserId("nonExistentUser")
        
        // Then
        XCTAssertNotNil(foundKey)
        XCTAssertEqual(foundKey?.kid, "kid1")
        XCTAssertNil(notFoundKey)
    }
    
    func testUserKeysStorage_DeleteByUserId() async throws {
        // Given
        let userKey1 = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        let userKey2 = UserKey(keyTag: "tag2", userId: "testUser2", username: "Test User 2", kid: "kid2", authType: .none)
        try await userKeyStorage.save(userKey: userKey1)
        try await userKeyStorage.save(userKey: userKey2)
        
        // When
        try await userKeyStorage.deleteByUserId("testUser")
        
        // Then
        let remainingKeys = try await userKeyStorage.findAll()
        XCTAssertEqual(remainingKeys.count, 1)
        XCTAssertEqual(remainingKeys.first?.userId, "testUser2")
    }
    
    func testSign_WithCustomClaims_InvalidClaim() async {
        // Given
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "testUser3"
        
        // When
        do {
            _ = try await Binding.sign(callback: signCallback, journey: nil, config: { config in
                config.claims = ["sub": "newSubject"] // "sub" is a reserved claim
            })
            XCTFail("Signing should have failed due to invalid custom claim.")
        } catch {
            // Then
            guard let deviceBindingError = error as? DeviceBindingError else {
                XCTFail("Error was not a DeviceBindingError.")
                return
            }
            XCTAssertEqual(deviceBindingError, .invalidClaim)
        }
    }
    
    // MARK: - Custom Claims Tests
    
    func testSign_WithValidCustomClaims() async {
        // Given
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "customClaimsUser"
        
        // When - Bind first
        do {
            _ = try await Binding.bind(callback: bindCallback, journey: nil)
            
            // Then - Sign with valid custom claims
            let signCallback = DeviceSigningVerifierCallback()
            signCallback.userId = "customClaimsUser"
            signCallback.challenge = "dGVzdGNoYWxsZW5nZQ=="
            
            let result = try await Binding.sign(callback: signCallback, journey: nil, config: { config in
                config.claims = [
                    "customField1": "value1",
                    "customField2": 42,
                    "customField3": true
                ]
            })
            
            XCTAssertNotNil(result)
            
            // Cleanup
            try await self.userKeyStorage.deleteByUserId("customClaimsUser")
        } catch {
            XCTFail("Signing with valid custom claims should succeed: \(error)")
        }
    }
    
    func testSign_WithMultipleReservedClaims() async {
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "reservedClaimsUser"
        // Test all reserved claim names
        let reservedClaims = ["iss", "sub", "exp", "nbf", "iat"]
        do {
            _ = try await Binding.bind(callback: bindCallback, journey: nil)
        }
        catch {
            XCTFail("Unexpected error for Binding: \(error)")
        }
        
        for reservedClaim in reservedClaims {
            let signCallback = DeviceSigningVerifierCallback()
            signCallback.userId = "reservedClaimsUser"
            
            do {
                _ = try await Binding.sign(callback: signCallback, journey: nil, config: { config in
                    config.claims = [reservedClaim: "value"]
                })
                XCTFail("Should have failed for reserved claim: \(reservedClaim)")
            } catch DeviceBindingError.invalidClaim {
                // Expected - test passed
            } catch {
                XCTFail("Unexpected error for claim \(reservedClaim): \(error)")
            }
        }
        
        do {
            // Cleanup
            try await self.userKeyStorage.deleteByUserId("customClaimsUser")
        }
        catch {
            XCTFail("Unexpected error for Cleanup: \(error)")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testDeviceBindingConfig_DefaultValues() {
        // Given
        let config = DeviceBindingConfig()
        
        // Then
        #if canImport(UIKit)
        XCTAssertEqual(config.deviceName, UIDevice.current.name)
        XCTAssertTrue(config.userKeySelector is DefaultUserKeySelector)
        #else
        XCTAssertEqual(config.deviceName, "Apple")
        #endif
        
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.attestation, .none)
        XCTAssertEqual(config.deviceBindingAuthenticationType, .none)
        XCTAssertTrue(config.claims.isEmpty)
    }
    
    func testDeviceBindingConfig_CustomValues() {
        // Given
        let config = DeviceBindingConfig()
        
        // When
        config.deviceName = "Test Device"
        config.timeout = 120
        config.attestation = .challenge("ghjh")
        config.deviceBindingAuthenticationType = .biometricOnly
        config.claims = ["custom": "value"]
        
        // Then
        XCTAssertEqual(config.deviceName, "Test Device")
        XCTAssertEqual(config.timeout, 120)
        XCTAssertEqual(config.attestation, .challenge("ghjh"))
        XCTAssertEqual(config.deviceBindingAuthenticationType, .biometricOnly)
        XCTAssertEqual(config.claims["custom"] as? String, "value")
    }
    
    func testDeviceBindingConfig_ES256AlgorithmAndKeySize() {
        // Given
        let config = DeviceBindingConfig()
        
        // Then - Verify ES256 is always used (P-256 curve with 256-bit keys)
        XCTAssertEqual(config.getSecKeyAlgorithm(), .ecdsaSignatureMessageX962SHA256)
        XCTAssertEqual(config.getKeySizeInBits(), 256)
    }
    
    func testDeviceBindingConfig_TimeFunctions() {
        // Given
        let config = DeviceBindingConfig()
        
        // When
        let issueTime = config.issueTime()
        let notBeforeTime = config.notBeforeTime()
        let expirationTime = config.expirationTime(60)
        
        // Then
        XCTAssertNotNil(issueTime)
        XCTAssertNotNil(notBeforeTime)
        XCTAssertNotNil(expirationTime)
        
        // Expiration should be approximately 60 seconds in the future
        let timeDifference = expirationTime.timeIntervalSince(issueTime)
        XCTAssertTrue(timeDifference >= 59 && timeDifference <= 61, "Expected ~60 seconds, got \(timeDifference)")
    }
    
    func testDeviceBindingConfig_CustomTimeFunctions() {
        // Given
        let config = DeviceBindingConfig()
        let customDate = Date(timeIntervalSince1970: 1000000)
        
        // When
        config.issueTime = { customDate }
        config.notBeforeTime = { customDate.addingTimeInterval(-10) }
        config.expirationTime = { seconds in customDate.addingTimeInterval(TimeInterval(seconds)) }
        
        // Then
        XCTAssertEqual(config.issueTime(), customDate)
        XCTAssertEqual(config.notBeforeTime(), customDate.addingTimeInterval(-10))
        XCTAssertEqual(config.expirationTime(30), customDate.addingTimeInterval(30))
    }
    
    // MARK: - Authenticator Configuration Tests
    
    func testAuthenticatorConfig_BiometricConfig() {
        // Given
        let config = BiometricAuthenticatorConfig()
        
        // When
        config.keyTag = "testKeyTag"
        
        // Then
        XCTAssertEqual(config.keyTag, "testKeyTag")
        XCTAssertNil(config.logger)
    }
    
    func testAuthenticatorConfig_AppPinConfig() {
        // Given
        let config = AppPinConfig()
        
        // When
        config.keyTag = "testKeyTag"
        
        // Then
        XCTAssertEqual(config.keyTag, "testKeyTag")
        XCTAssertEqual(config.pinRetry, 3)
        XCTAssertNil(config.logger)
    }
    
    // MARK: - Prompt Tests
    
    func testPrompt_Creation() {
        // Given & When
        let prompt = Prompt(title: "Test title", subtitle: "Test subtitle", description: "Test Description")
        
        // Then
        XCTAssertEqual(prompt.title, "Test title")
        XCTAssertEqual(prompt.subtitle, "Test subtitle")
        XCTAssertEqual(prompt.description, "Test Description")
    }
    
    func testPrompt_EmptyValues() {
        // Given & When
        let prompt = Prompt(title: "", subtitle: "", description: "")
        
        // Then
        XCTAssertEqual(prompt.title, "")
        XCTAssertEqual(prompt.subtitle, "")
        XCTAssertEqual(prompt.description, "")
    }
    
    // MARK: - UserKey Model Tests
    
    func testUserKey_Properties() {
        // Given
        let keyId = UUID().uuidString
        let userId = "testUser3"
        let userName = "Test User"
        
        let keyAlias = "test.key.alias"
        
        let userKey = UserKey(keyTag: keyAlias, userId: userId, username: userName, kid: keyId, authType: .none)
        let createdAt = Date()
        XCTAssertEqual(userKey.createdAt.timeIntervalSince(createdAt), 0, accuracy: 0.01)
        XCTAssertEqual(userKey.id, keyId)
        XCTAssertEqual(userKey.userId, userId)
        XCTAssertEqual(userKey.username, userName)
        XCTAssertEqual(userKey.authType, .none)
        XCTAssertEqual(userKey.keyTag, keyAlias)
    }
    
    // MARK: - Storage Edge Cases
    
    func testUserKeysStorage_DeleteNonExistentUser() async {
        // Given
        let nonExistentUserId = "nonExistentUser_\(UUID().uuidString)"
        
        // When & Then - Deleting a non-existent user should not throw
        do {
            try await self.userKeyStorage.deleteByUserId(nonExistentUserId)
        } catch {
            XCTFail("Deleting non-existent user should not throw: \(error)")
        }
    }
    
    func testUserKeysStorage_FindNonExistentUser() async {
        // Given
        let nonExistentUserId = "nonExistentUser_\(UUID().uuidString)"
        
        // When
        do {
            let keys = try await userKeyStorage.findByUserId(nonExistentUserId)
            // Then
            XCTAssertNil(keys)
        } catch {
            XCTFail("Finding non-existent user should not throw: \(error)")
        }
    }
    
    func testUserKeysStorage_ConcurrentAccess() async {
        // Test concurrent read/write operations
        let bindCallback1 = DeviceBindingCallback()
        bindCallback1.userId = "concurrent1"
        
        let bindCallback2 = DeviceBindingCallback()
        bindCallback2.userId = "concurrent2"
        
        do {
            // Execute bindings concurrently
            async let bind1 = Binding.bind(callback: bindCallback1, journey: nil)
            async let bind2 = Binding.bind(callback: bindCallback2, journey: nil)
            
            let (_, _) = try await (bind1, bind2)
            
            XCTFail("testUserKeysStorage_ConcurrentAccess Expected to fail")
            
        } catch {
            // Cleanup
            try? await userKeyStorage.deleteByUserId("concurrent1")
            try? await userKeyStorage.deleteByUserId("concurrent2")
        }
    }
    
    // MARK: - Callback Tests
    
    func testDeviceBindingCallback_InitValue() {
        // Given
        let callback = DeviceBindingCallback()
        
        // When
        callback.userId = "testUser3"
        
        // Then
        XCTAssertEqual(callback.userId, "testUser3")
    }
    
    func testDeviceSigningVerifierCallback_InitValue() {
        // Given
        let callback = DeviceSigningVerifierCallback()
        
        // When
        callback.userId = "testUser3"
        callback.challenge = "challenge123"
        callback.title = "Sign Request"
        callback.subtitle = "Please authenticate"
        
        // Then
        XCTAssertEqual(callback.userId, "testUser3")
        XCTAssertEqual(callback.challenge, "challenge123")
        XCTAssertEqual(callback.title, "Sign Request")
        XCTAssertEqual(callback.subtitle, "Please authenticate")
    }
    
    // MARK: - DeviceBindingAuthenticationType Tests
    
    func testDeviceBindingAuthenticationType_BiometricOnly() {
        // Given
        let authType = DeviceBindingAuthenticationType.biometricOnly
        
        // Then
        XCTAssertNotNil(authType)
        XCTAssertEqual(authType, .biometricOnly)
    }
    
    func testDeviceBindingAuthenticationType_BiometricAllowFallback() {
        // Given
        let authType = DeviceBindingAuthenticationType.biometricAllowFallback
        
        // Then
        XCTAssertNotNil(authType)
        XCTAssertEqual(authType, .biometricAllowFallback)
    }
    
    func testDeviceBindingAuthenticationType_ApplicationPin() {
        // Given
        let authType = DeviceBindingAuthenticationType.applicationPin
        
        // Then
        XCTAssertNotNil(authType)
        XCTAssertEqual(authType, .applicationPin)
    }
    
    func testDeviceBindingAuthenticationType_None() {
        // Given
        let authType = DeviceBindingAuthenticationType.none
        
        // Then
        XCTAssertNotNil(authType)
        XCTAssertEqual(authType, .none)
    }
    
    // MARK: - Error Type Tests
    
    func testDeviceBindingError_Equality() {
        // Test equality for each error type
        XCTAssertEqual(DeviceBindingError.authenticationFailed, DeviceBindingError.authenticationFailed)
        XCTAssertEqual(DeviceBindingError.deviceNotSupported, DeviceBindingError.deviceNotSupported)
        XCTAssertEqual(DeviceBindingError.deviceNotRegistered, DeviceBindingError.deviceNotRegistered)
        XCTAssertEqual(DeviceBindingError.invalidClaim, DeviceBindingError.invalidClaim)
        XCTAssertEqual(DeviceBindingError.userCanceled, DeviceBindingError.userCanceled)
        XCTAssertEqual(DeviceBindingError.timeout, DeviceBindingError.timeout)
        XCTAssertEqual(DeviceBindingError.unknown, DeviceBindingError.unknown)
        
        // Test inequality
        XCTAssertNotEqual(DeviceBindingError.authenticationFailed, DeviceBindingError.userCanceled)
        XCTAssertNotEqual(DeviceBindingError.timeout, DeviceBindingError.unknown)
    }
    
    func testDeviceBindingError_ToClientError() {
        // Test error conversion to client error strings
        XCTAssertEqual(DeviceBindingError.deviceNotRegistered.toClientError(), DeviceBindingStatus.clientNotRegistered.clientError)
        XCTAssertEqual(DeviceBindingError.timeout.toClientError(), DeviceBindingStatus.timeout.clientError)
        XCTAssertEqual(DeviceBindingError.authenticationFailed.toClientError(), DeviceBindingStatus.abort.clientError)
        XCTAssertEqual(DeviceBindingError.userCanceled.toClientError(), DeviceBindingStatus.abort.clientError)
        XCTAssertEqual(DeviceBindingError.deviceNotSupported.toClientError(), DeviceBindingStatus.unsupported(errorMessage: "Device not supported").clientError)
    }
    
    // MARK: - Attestation Tests
    
    func testAttestation_None() {
        // Given
        let config = DeviceBindingConfig()
        
        // When
        config.attestation = .none
        
        // Then
        XCTAssertEqual(config.attestation, .none)
    }
}
