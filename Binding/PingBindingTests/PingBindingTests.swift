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
@testable import PingJourney

final class PingBindingTests: XCTestCase {
    
    var userKeyStorage: UserKeysStorage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = UserKeyStorageConfig(fileName: "test_user_keys.json")
        userKeyStorage = UserKeysStorage(config: config)
        // Clean up before each test
        try? userKeyStorage.deleteByUserId("testUser")
        try? userKeyStorage.deleteByUserId("testUser2")
    }
    
    override func tearDownWithError() throws {
        // Clean up after each test
        try? userKeyStorage.deleteByUserId("testUser")
        try? userKeyStorage.deleteByUserId("testUser2")
        userKeyStorage = nil
        try super.tearDownWithError()
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
            let jws = try await PingBinder.bind(callback: callback, journey: nil)
            
            // Then
            XCTAssertFalse(jws.isEmpty)
            
            let storedKey = try userKeyStorage.findByUserId("testUser")
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
            _ = try await PingBinder.bind(callback: bindCallback, journey: nil)
            
            // Now, prepare for signing
            let signCallback = DeviceSigningVerifierCallback()
            signCallback.userId = "testUser"
            signCallback.challenge = "anotherChallenge"
            
            // When
            let jws = try await PingBinder.sign(callback: signCallback, journey: nil)
            
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
            _ = try await PingBinder.sign(callback: signCallback, journey: nil)
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
            _ = try await PingBinder.bind(callback: firstBindCallback, journey: nil)
            
            let firstKey = try userKeyStorage.findByUserId("testUser")
            XCTAssertNotNil(firstKey, "First key should be stored.")
            
            // When: Bind the same user again
            let secondBindCallback = DeviceBindingCallback()
            secondBindCallback.userId = "testUser"
            secondBindCallback.userName = "Test User"
            secondBindCallback.challenge = "secondChallenge"
            _ = try await PingBinder.bind(callback: secondBindCallback, journey: nil)
            
            // Then
            let allKeys = try userKeyStorage.findAll()
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
    
    func testUserKeysStorage_SaveAndFindAll() throws {
        // Given
        let userKey1 = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        let userKey2 = UserKey(keyTag: "tag2", userId: "testUser2", username: "Test User 2", kid: "kid2", authType: .none)
        
        // When
        try userKeyStorage.save(userKey: userKey1)
        try userKeyStorage.save(userKey: userKey2)
        
        // Then
        let allKeys = try userKeyStorage.findAll()
        XCTAssertEqual(allKeys.count, 2)
        XCTAssertTrue(allKeys.contains(where: { $0.userId == "testUser" }))
        XCTAssertTrue(allKeys.contains(where: { $0.userId == "testUser2" }))
    }
    
    func testUserKeysStorage_FindByUserId() throws {
        // Given
        let userKey = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        try userKeyStorage.save(userKey: userKey)
        
        // When
        let foundKey = try userKeyStorage.findByUserId("testUser")
        let notFoundKey = try userKeyStorage.findByUserId("nonExistentUser")
        
        // Then
        XCTAssertNotNil(foundKey)
        XCTAssertEqual(foundKey?.kid, "kid1")
        XCTAssertNil(notFoundKey)
    }
    
    func testUserKeysStorage_DeleteByUserId() throws {
        // Given
        let userKey1 = UserKey(keyTag: "tag1", userId: "testUser", username: "Test User", kid: "kid1", authType: .none)
        let userKey2 = UserKey(keyTag: "tag2", userId: "testUser2", username: "Test User 2", kid: "kid2", authType: .none)
        try userKeyStorage.save(userKey: userKey1)
        try userKeyStorage.save(userKey: userKey2)
        
        // When
        try userKeyStorage.deleteByUserId("testUser")
        
        // Then
        let remainingKeys = try userKeyStorage.findAll()
        XCTAssertEqual(remainingKeys.count, 1)
        XCTAssertEqual(remainingKeys.first?.userId, "testUser2")
    }
    
    func testSign_WithCustomClaims_InvalidClaim() async {
        // Given
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "testUser"
        
        // When
        do {
            _ = try await PingBinder.sign(callback: signCallback, journey: nil, config: { config in
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
}
