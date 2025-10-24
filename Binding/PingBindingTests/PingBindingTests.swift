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

    func testBind_Success() async throws {
        // Given
        let callback = DeviceBindingCallback()
        callback.userId = "testUser"
        callback.userName = "Test User"
        callback.challenge = "challenge"
        callback.deviceBindingAuthenticationType = .none

        // When
        try await callback.bind()

        // Then
        let jws = (callback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == Constants.jws })?[JourneyConstants.value]
        XCTAssertNotNil(jws)
        
        let storedKey = try userKeyStorage.findByUserId("testUser")
        XCTAssertNotNil(storedKey)
        XCTAssertEqual(storedKey?.userId, "testUser")
    }
    
    func testSign_Success() async throws {
        // Given: First, bind a device
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "testUser"
        bindCallback.userName = "Test User"
        bindCallback.challenge = "challenge"
        bindCallback.deviceBindingAuthenticationType = .none
        try await bindCallback.bind()
        
        // Now, prepare for signing
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "testUser"
        signCallback.challenge = "anotherChallenge"
        
        // When
        try await signCallback.sign()
        
        // Then
        let jws = (signCallback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == Constants.jws })?[JourneyConstants.value]
        XCTAssertNotNil(jws)
    }
    
    func testSign_FailsWhenNotRegistered() async {
        // Given
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "nonExistentUser"
        signCallback.challenge = "challenge"
        
        // When
        do {
            try await signCallback.sign()
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
    
    func testBind_ClearsPreviousKeysForSameUser() async throws {
        // Given: Bind a user first
        let firstBindCallback = DeviceBindingCallback()
        firstBindCallback.userId = "testUser"
        firstBindCallback.userName = "Test User"
        firstBindCallback.challenge = "firstChallenge"
        try await firstBindCallback.bind()
        
        let firstKey = try userKeyStorage.findByUserId("testUser")
        XCTAssertNotNil(firstKey, "First key should be stored.")
        
        // When: Bind the same user again
        let secondBindCallback = DeviceBindingCallback()
        secondBindCallback.userId = "testUser"
        secondBindCallback.userName = "Test User"
        secondBindCallback.challenge = "secondChallenge"
        try await secondBindCallback.bind()
        
        // Then
        let allKeys = try userKeyStorage.findAll()
        let userKeys = allKeys.filter { $0.userId == "testUser" }
        
        XCTAssertEqual(userKeys.count, 1, "There should be only one key for the user.")
        let newKey = userKeys.first
        XCTAssertNotEqual(newKey?.keyTag, firstKey?.keyTag, "The new key should have a different keyTag.")
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
            try await signCallback.sign(config: { config in
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
    
    func testSign_Success() async throws {
        // Given: First, bind a device
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "testUser"
        bindCallback.userName = "Test User"
        bindCallback.challenge = "challenge"
        bindCallback.deviceBindingAuthenticationType = .none
        _ = try await PingBinder.bind(callback: bindCallback)
        
        // Now, prepare for signing
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "testUser"
        signCallback.challenge = "anotherChallenge"
        
        // When
        let jws = try await PingBinder.sign(callback: signCallback)
        
        // Then
        XCTAssertFalse(jws.isEmpty)
    }
    
    func testSign_FailsWhenNotRegistered() async {
        // Given
        let signCallback = DeviceSigningVerifierCallback()
        signCallback.userId = "nonExistentUser"
        signCallback.challenge = "challenge"
        
        // When
        do {
            _ = try await PingBinder.sign(callback: signCallback)
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
    
    func testBind_ClearsPreviousKeysForSameUser() async throws {
        // Given: Bind a user first
        let firstBindCallback = DeviceBindingCallback()
        firstBindCallback.userId = "testUser"
        firstBindCallback.userName = "Test User"
        firstBindCallback.challenge = "firstChallenge"
        _ = try await PingBinder.bind(callback: firstBindCallback)
        
        let firstKey = try userKeyStorage.findByUserId("testUser")
        XCTAssertNotNil(firstKey, "First key should be stored.")
        
        // When: Bind the same user again
        let secondBindCallback = DeviceBindingCallback()
        secondBindCallback.userId = "testUser"
        secondBindCallback.userName = "Test User"
        secondBindCallback.challenge = "secondChallenge"
        _ = try await PingBinder.bind(callback: secondBindCallback)
        
        // Then
        let allKeys = try userKeyStorage.findAll()
        let userKeys = allKeys.filter { $0.userId == "testUser" }
        
        XCTAssertEqual(userKeys.count, 1, "There should be only one key for the user.")
        let newKey = userKeys.first
        XCTAssertNotEqual(newKey?.keyTag, firstKey?.keyTag, "The new key should have a different keyTag.")
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
            _ = try await PingBinder.sign(callback: signCallback, config: { config in
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
