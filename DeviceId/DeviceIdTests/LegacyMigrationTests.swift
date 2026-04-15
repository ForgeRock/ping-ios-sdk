//
//  LegacyMigrationTests.swift
//  DeviceIdTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CommonCrypto
@testable import PingDeviceId
@testable import PingStorage

/// Comprehensive tests for legacy FRAuth SDK device identifier migration
final class LegacyMigrationTests: XCTestCase {
    
    var deviceIdentifier: DefaultDeviceIdentifier!
    
    override func setUp() async throws {
        try await super.setUp()
        await cleanupAllKeychain()
    }
    
    override func tearDown() async throws {
        await cleanupAllKeychain()
        deviceIdentifier = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupAllKeychain() async {
        // Clean up new storage
        let newStorage = KeychainStorage<DeviceIdentifierImpl>(
            account: Constants.deviceIdentifierKey,
            encryptor: NoEncryptor()
        )
        try? await newStorage.delete()
        
        // Clean up legacy storage
        let legacyKeys = [
            LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
            LegacyDeviceIdentifier.LegacyKeychainKeys.privateKeyData
        ]
        
        for key in legacyKeys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
    
    private func storeLegacyIdentifier(_ identifier: String) {
        guard let data = identifier.data(using: .utf8) else {
            XCTFail("Failed to encode identifier")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess, "Failed to store legacy identifier")
    }
    
    private func storeLegacyPublicKeyData(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess, "Failed to store legacy public key data")
    }
    
    private func generateLegacyHash(from data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(bytes: digest, count: digest.count).toHexString()
    }
    
    private func verifyIdentifierInNewStorage(_ expectedId: String) async throws {
        let storage = KeychainStorage<DeviceIdentifierImpl>(
            account: Constants.deviceIdentifierKey,
            encryptor: NoEncryptor()
        )
        
        let stored = try await storage.get()
        XCTAssertNotNil(stored, "Identifier should be stored in new format")
        
        let id = try await stored?.id
        XCTAssertEqual(id, expectedId, "Migrated identifier should match")
    }
    
    // MARK: - Migration Tests
    
    func testMigration_WithLegacyIdentifier_MigratesSuccessfully() async throws {
        // Given
        let legacyId = "abc123def456legacy"
        storeLegacyIdentifier(legacyId)
        
        // When
        deviceIdentifier = try DefaultDeviceIdentifier()
        let retrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(retrievedId, legacyId, "Should return migrated legacy identifier")
        try await verifyIdentifierInNewStorage(legacyId)
    }
    
    func testMigration_WithPublicKeyOnly_RegeneratesIdentifier() async throws {
        // Given
        let testKeyData = "test-public-key-data".data(using: .utf8)!
        storeLegacyPublicKeyData(testKeyData)
        let expectedHash = generateLegacyHash(from: testKeyData)
        
        // When
        deviceIdentifier = try DefaultDeviceIdentifier()
        let retrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(retrievedId, expectedHash, "Should regenerate identifier from public key")
        try await verifyIdentifierInNewStorage(expectedHash)
    }
    
    func testMigration_NoLegacyData_GeneratesNewIdentifier() async throws {
        // When
        deviceIdentifier = try DefaultDeviceIdentifier()
        let firstId = try await deviceIdentifier.id
        
        // Then
        XCTAssertFalse(firstId.isEmpty, "Should generate new identifier")
        XCTAssertEqual(firstId.count, 64, "New identifiers should use SHA-256 (64 hex chars)")
        
        let secondId = try await deviceIdentifier.id
        XCTAssertEqual(firstId, secondId, "Identifier should be consistent")
    }
    
    func testMigration_LegacyIdentifierPersistsAcrossRestart() async throws {
        // Given
        let legacyId = "persistent-legacy-id"
        storeLegacyIdentifier(legacyId)
        
        deviceIdentifier = try DefaultDeviceIdentifier()
        let firstRetrievedId = try await deviceIdentifier.id
        XCTAssertEqual(firstRetrievedId, legacyId)
        
        // When: "App restarts"
        deviceIdentifier = try DefaultDeviceIdentifier()
        let secondRetrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(secondRetrievedId, legacyId, "Migrated identifier should persist")
    }
    
    func testMigration_RegenerateAfterMigration_CreatesNewIdentifier() async throws {
        // Given
        let legacyId = "legacy-to-regenerate"
        storeLegacyIdentifier(legacyId)
        
        deviceIdentifier = try DefaultDeviceIdentifier()
        let migratedId = try await deviceIdentifier.id
        XCTAssertEqual(migratedId, legacyId)
        
        // When
        let newId = try await deviceIdentifier.regenerateIdentifier()
        
        // Then
        XCTAssertNotEqual(newId, legacyId, "Regenerated ID should be different from legacy")
        XCTAssertEqual(newId.count, 64, "New ID should use SHA-256")
        
        // Verify legacy storage is cleared
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
        XCTAssertEqual(status, errSecItemNotFound, "Legacy identifier should be deleted")
    }
    
    func testMigration_ConcurrentAccess_NoDuplicateMigration() async throws {
        // Given
        let legacyId = "concurrent-legacy-id"
        storeLegacyIdentifier(legacyId)
        
        deviceIdentifier = try DefaultDeviceIdentifier()
        
        // When
        async let id1 = deviceIdentifier.id
        async let id2 = deviceIdentifier.id
        async let id3 = deviceIdentifier.id
        
        let ids = try await [id1, id2, id3]
        
        // Then
        XCTAssertEqual(Set(ids).count, 1, "All concurrent accesses should return same ID")
        XCTAssertEqual(ids.first, legacyId, "Should return migrated legacy ID")
    }
    
    func testMigration_LegacyUsingSHA1_NewUsesSHA256() async throws {
        // Given: Legacy identifier (SHA-1 based, 40 hex chars)
        let legacyId = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" // 40 chars
        storeLegacyIdentifier(legacyId)
        
        deviceIdentifier = try DefaultDeviceIdentifier()
        let migratedId = try await deviceIdentifier.id
        
        // Then: Legacy ID preserved as-is
        XCTAssertEqual(migratedId.count, 40, "Legacy SHA-1 hash should be 40 chars")
        XCTAssertEqual(migratedId, legacyId)
        
        // When: Regenerating
        let newId = try await deviceIdentifier.regenerateIdentifier()
        
        // Then: New ID uses SHA-256
        XCTAssertEqual(newId.count, 64, "New SHA-256 hash should be 64 chars")
        XCTAssertNotEqual(newId, legacyId)
    }
    
    func testMigration_WithEncryptionEnabled_MigratesSuccessfully() async throws {
        // Given
        let legacyId = "encrypted-legacy-id"
        storeLegacyIdentifier(legacyId)
        
        let config = DeviceIdentifierConfiguration(
            keySize: 2048,
            keychainAccount: Constants.deviceIdentifierKey,
            useEncryption: true
        )
        
        // When
        deviceIdentifier = try DefaultDeviceIdentifier(configuration: config)
        let retrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(retrievedId, legacyId, "Should migrate even with encryption enabled")
    }
    
    func testMigration_CustomConfiguration_FindsLegacyIdentifier() async throws {
        // Given
        let customAccount = "com.test.custom.deviceid"
        let config = DeviceIdentifierConfiguration(
            keySize: 2048,
            keychainAccount: customAccount,
            useEncryption: false
        )
        
        let legacyId = "legacy-id-different-account"
        storeLegacyIdentifier(legacyId)
        
        // When
        deviceIdentifier = try DefaultDeviceIdentifier(configuration: config)
        let retrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(retrievedId, legacyId, "Should find legacy identifier regardless of config")
        
        // Verify stored in custom account
        let customStorage = KeychainStorage<DeviceIdentifierImpl>(
            account: customAccount,
            encryptor: NoEncryptor()
        )
        let stored = try await customStorage.get()
        XCTAssertNotNil(stored, "Should store in custom location")
    }
}

extension Data {
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
