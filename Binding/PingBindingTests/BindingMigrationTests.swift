//
//  BindingMigrationTests.swift
//  PingBindingTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBinding
import PingStorage

final class BindingMigrationTests: XCTestCase {
    
    let legacyKeychainService = "com.forgerock.ios.devicebinding.keychainservice"
    let legacyAccount = "devicebinding.userkeys"
    let testUserId1 = "test-user-1"
    let testUserId2 = "test-user-2"
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Clean up any existing data before each test
        await cleanupAllData()
        await BindingMigration.resetMigrationState()
    }
    
    override func tearDown() async throws {
        // Clean up after each test
        await cleanupAllData()
        await BindingMigration.resetMigrationState()
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Cleans up all keychain data used in tests
    func cleanupAllData() async {
        // Delete legacy keychain data
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(legacyQuery as CFDictionary)
        
        // Delete new storage data
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        try? await newStorage.deleteAll()
        
        // Delete any crypto keys
        for userId in [testUserId1, testUserId2] {
            let cryptoKey = CryptoKey(keyTag: "test-key-\(userId)")
            try? cryptoKey.deleteKeyPair()
        }
    }
    
    /// Creates mock legacy user keys in the keychain
    func createLegacyUserKeys(_ userKeys: [UserKey]) throws {
        let data = try JSONEncoder().encode(userKeys)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: legacyAccount,
            kSecValueData as String: data
        ]
        
        // Delete any existing entry first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess, "Failed to create legacy keychain data")
    }
    
    /// Creates sample user keys for testing
    func createSampleUserKeys() -> [UserKey] {
        return [
            UserKey(
                keyTag: "test-key-\(testUserId1)",
                userId: testUserId1,
                username: "testuser1",
                kid: "kid-1",
                authType: .biometricOnly
            ),
            UserKey(
                keyTag: "test-key-\(testUserId2)",
                userId: testUserId2,
                username: "testuser2",
                kid: "kid-2",
                authType: .applicationPin
            )
        ]
    }
    
    // MARK: - LegacyUserKeysStorage Tests
    
    func testLegacyStorageExists_WhenNoDataExists() async throws {
        let legacyStorage = LegacyUserKeysStorage()
        
        let exists = await legacyStorage.exists()
        
        XCTAssertFalse(exists, "Legacy storage should not exist when no data is present")
    }
    
    func testLegacyStorageExists_WhenDataExists() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        let legacyStorage = LegacyUserKeysStorage()
        let exists = await legacyStorage.exists()
        
        XCTAssertTrue(exists, "Legacy storage should exist when data is present")
    }
    
    func testLegacyStorageGetAllKeys_ReturnsCorrectKeys() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        let legacyStorage = LegacyUserKeysStorage()
        let retrievedKeys = try await legacyStorage.getAllKeys()
        
        XCTAssertEqual(retrievedKeys.count, 2, "Should retrieve 2 keys")
        XCTAssertTrue(retrievedKeys.contains(where: { $0.userId == testUserId1 }))
        XCTAssertTrue(retrievedKeys.contains(where: { $0.userId == testUserId2 }))
    }
    
    func testLegacyStorageGetAllKeys_ThrowsErrorWhenNoData() async throws {
        let legacyStorage = LegacyUserKeysStorage()
        
        do {
            _ = try await legacyStorage.getAllKeys()
            XCTFail("Should throw MigrationError.noLegacyDataFound")
        } catch MigrationError.noLegacyDataFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLegacyStorageDeleteLegacyData_RemovesData() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        let legacyStorage = LegacyUserKeysStorage()
        
        // Verify data exists
        let existsBefore = await legacyStorage.exists()
        XCTAssertTrue(existsBefore)
        
        // Delete data
        try await legacyStorage.deleteLegacyData()
        
        // Verify data is gone
        let existsAfter = await legacyStorage.exists()
        XCTAssertFalse(existsAfter)
    }
    
    // MARK: - BindingMigration Tests
    
    func testMigration_SuccessfullyMigratesLegacyKeys() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        // Perform migration
        try await BindingMigration.migrate()
        
        // Verify keys are in new storage
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        let migratedKeys = try await newStorage.findAll()
        
        XCTAssertEqual(migratedKeys.count, 2, "Should have migrated 2 keys")
        XCTAssertTrue(migratedKeys.contains(where: { $0.userId == testUserId1 }))
        XCTAssertTrue(migratedKeys.contains(where: { $0.userId == testUserId2 }))
        
        // Verify legacy data is deleted
        let legacyStorage = LegacyUserKeysStorage()
        let legacyExists = await legacyStorage.exists()
        XCTAssertFalse(legacyExists, "Legacy data should be deleted")
    }
    
    func testMigration_ThrowsErrorWhenNoLegacyData() async throws {
        do {
            try await BindingMigration.migrate()
            XCTFail("Should throw MigrationError.noLegacyDataFound")
        } catch MigrationError.noLegacyDataFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMigration_DoesNotDuplicateExistingKeys() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        // Add one key to new storage before migration
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        let existingKey = userKeys[0]
        try await newStorage.save(userKey: existingKey)
        
        // Perform migration
        try await BindingMigration.migrate()
        
        // Verify we don't have duplicates
        let allKeys = try await newStorage.findAll()
        let user1Keys = allKeys.filter { $0.userId == testUserId1 }
        
        XCTAssertEqual(user1Keys.count, 1, "Should not duplicate existing key")
        XCTAssertEqual(allKeys.count, 2, "Should have 2 total keys")
    }
    
    func testMigration_OnlyRunsOnce() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        // First migration
        try await BindingMigration.migrate()
        
        // Recreate legacy data
        try createLegacyUserKeys(userKeys)
        
        // Second migration attempt should skip
        try? await BindingMigration.migrate()
        
        // Should still only have 2 keys (not duplicated)
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        let allKeys = try await newStorage.findAll()
        
        XCTAssertEqual(allKeys.count, 2, "Should not migrate again")
    }
    
    func testMigration_WithCleanupDisabled_PreservesLegacyData() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        // Reset state to allow migration
        await BindingMigration.resetMigrationState()
        
        // Perform migration without cleanup
        try await BindingMigration.migrate(cleanupLegacyData: false)
        
        // Verify keys are migrated
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        let migratedKeys = try await newStorage.findAll()
        XCTAssertEqual(migratedKeys.count, 2)
        
        // Verify legacy data still exists
        let legacyStorage = LegacyUserKeysStorage()
        let legacyStillExists = await legacyStorage.exists()
        XCTAssertTrue(legacyStillExists, "Legacy data should be preserved")
    }
    
    func testMigration_WithAccessGroup() async throws {
        // Note: Access group testing requires proper entitlements
        // This test verifies the parameter is accepted
        
        do {
            try await BindingMigration.migrate(accessGroup: "com.test.group")
        } catch MigrationError.noLegacyDataFound {
            // Expected when no data exists
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMigration_PreservesKeyProperties() async throws {
        let originalKey = UserKey(
            keyTag: "test-tag",
            userId: "user-123",
            username: "testuser",
            kid: "key-id-123",
            authType: .biometricOnly
        )
        
        try createLegacyUserKeys([originalKey])
        
        // Perform migration
        try await BindingMigration.migrate()
        
        // Retrieve migrated key
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        let migratedKey = try await newStorage.findByUserId("user-123")
        
        XCTAssertNotNil(migratedKey)
        XCTAssertEqual(migratedKey?.keyTag, originalKey.keyTag)
        XCTAssertEqual(migratedKey?.userId, originalKey.userId)
        XCTAssertEqual(migratedKey?.username, originalKey.username)
        XCTAssertEqual(migratedKey?.kid, originalKey.kid)
        XCTAssertEqual(migratedKey?.authType, originalKey.authType)
    }
    
    func testMigration_HandlesInvalidLegacyData() async throws {
        // Create invalid JSON in legacy storage
        let invalidData = "invalid json data".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: legacyAccount,
            kSecValueData as String: invalidData
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)
        
        // Attempt migration
        do {
            try await BindingMigration.migrate()
            XCTFail("Should throw MigrationError.invalidLegacyData")
        } catch MigrationError.invalidLegacyData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMigration_HandlesEmptyLegacyArray() async throws {
        // Create empty array in legacy storage
        try createLegacyUserKeys([])
        
        do {
            try await BindingMigration.migrate()
            XCTFail("Should throw MigrationError.noLegacyDataFound")
        } catch MigrationError.noLegacyDataFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMigration_ResetState_AllowsRemigration() async throws {
        let userKeys = createSampleUserKeys()
        try createLegacyUserKeys(userKeys)
        
        // First migration
        try await BindingMigration.migrate()
        
        // Clean up new storage
        let newStorage = UserKeysStorage(config: UserKeyStorageConfig())
        try await newStorage.deleteAll()
        
        // Recreate legacy data
        try createLegacyUserKeys(userKeys)
        
        // Reset state
        await BindingMigration.resetMigrationState()
        
        // Second migration should succeed
        try await BindingMigration.migrate()
        
        let migratedKeys = try await newStorage.findAll()
        XCTAssertEqual(migratedKeys.count, 2, "Should migrate again after reset")
    }
    
    // MARK: - MigrationError Tests
    
    func testMigrationError_HasCorrectDescriptions() {
        let testError = NSError(domain: "test", code: 1)
        
        let errors: [(MigrationError, String)] = [
            (.noLegacyDataFound, "No legacy data found to migrate"),
            (.alreadyMigrated, "Migration has already been completed"),
            (.failedToReadLegacyKeys(testError), "Failed to read legacy user keys"),
            (.failedToSaveKeys(testError), "Failed to save migrated keys"),
            (.failedToDeleteLegacyData(testError), "Failed to delete legacy data"),
            (.invalidLegacyData("test message"), "Invalid legacy data: test message")
        ]
        
        for (error, expectedPrefix) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.contains(expectedPrefix) || description.hasPrefix(expectedPrefix),
                "Error description '\(description)' should contain '\(expectedPrefix)'"
            )
        }
    }
}
