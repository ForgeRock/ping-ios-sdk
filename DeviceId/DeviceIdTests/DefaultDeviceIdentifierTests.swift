//
//  DefaultDeviceIdentifierTests.swift
//  DeviceIdTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceId
@testable import PingStorage

/// Tests for `DefaultDeviceIdentifier` core functionality
final class DefaultDeviceIdentifierTests: XCTestCase {
    
    var deviceIdentifier: DefaultDeviceIdentifier!
    
    override func setUp() async throws {
        try await super.setUp()
        // Clean up any existing data
        await cleanupKeychain()
        
        // Create a fresh instance for each test
        deviceIdentifier = try DefaultDeviceIdentifier(configuration: .default)
    }
    
    override func tearDown() async throws {
        await cleanupKeychain()
        deviceIdentifier = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupKeychain() async {
        // Clean up new storage
        let storage = KeychainStorage<DeviceIdentifierImpl>(
            account: Constants.deviceIdentifierKey,
            encryptor: NoEncryptor()
        )
        try? await storage.delete()
        
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
    
    // MARK: - Core Functionality Tests
    
    func testIdentifierGeneration_CreatesValidIdentifier() async throws {
        // When
        let id = try await deviceIdentifier.id
        
        // Then: Should be a valid SHA-256 hash (64 hex characters)
        XCTAssertEqual(id.count, 64, "SHA-256 hash should be 64 hex characters")
        XCTAssertTrue(id.allSatisfy { $0.isHexDigit }, "Identifier should only contain hex characters")
    }
    
    func testIdentifierConsistency_ReturnsSameValueOnMultipleAccess() async throws {
        // When
        let id1 = try await deviceIdentifier.id
        let id2 = try await deviceIdentifier.id
        let id3 = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(id1, id2, "Identifier should be consistent")
        XCTAssertEqual(id2, id3, "Identifier should be consistent")
    }
    
    func testIdentifierPersistence_MaintainsAcrossInstances() async throws {
        // Given
        let firstId = try await deviceIdentifier.id
        
        // When: Creating new instance
        deviceIdentifier = try DefaultDeviceIdentifier(configuration: .default)
        let secondId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(firstId, secondId, "Identifier should persist across instances")
    }
    
    func testConcurrentAccess_NoDuplicateGeneration() async throws {
        // When: Multiple concurrent access attempts
        async let id1 = deviceIdentifier.id
        async let id2 = deviceIdentifier.id
        async let id3 = deviceIdentifier.id
        async let id4 = deviceIdentifier.id
        
        let ids = try await [id1, id2, id3, id4]
        
        // Then: All should return the same identifier
        XCTAssertEqual(Set(ids).count, 1, "Concurrent access should return same ID")
    }
    
    func testClearCache_DoesNotAffectPersistedIdentifier() async throws {
        // Given
        let originalId = try await deviceIdentifier.id
        
        // When
        deviceIdentifier.clearCache()
        let retrievedId = try await deviceIdentifier.id
        
        // Then
        XCTAssertEqual(originalId, retrievedId, "Clearing cache should not change identifier")
    }
    
    func testRegenerateIdentifier_CreatesNewIdentifier() async throws {
        // Given
        let firstId = try await deviceIdentifier.id
        
        // When
        let newId = try await deviceIdentifier.regenerateIdentifier()
        
        // Then
        XCTAssertNotEqual(firstId, newId, "Regenerated ID should be different")
        XCTAssertEqual(newId.count, 64, "New ID should be SHA-256 hash")
        
        // And: New ID should be persistent
        let retrievedId = try await deviceIdentifier.id
        XCTAssertEqual(newId, retrievedId, "Regenerated ID should be accessible")
    }
    
    func testCustomConfiguration_UsesCorrectSettings() async throws {
        // Given
        let customConfig = DeviceIdentifierConfiguration(
            keySize: 4096,
            keychainAccount: "com.test.custom",
            useEncryption: true
        )
        
        // When
        let customIdentifier = try DefaultDeviceIdentifier(configuration: customConfig)
        let id = try await customIdentifier.id
        
        // Then
        XCTAssertEqual(id.count, 64, "Should generate valid identifier with custom config")
        
        // Verify stored in custom account
        let customStorage = KeychainStorage<DeviceIdentifierImpl>(
            account: "com.test.custom",
            encryptor: NoEncryptor()
        )
        let stored = try await customStorage.get()
        XCTAssertNotNil(stored, "Should store in custom account")
    }
    
    func testHighSecurityConfiguration_UsesLargerKeySize() async throws {
        // Given
        let secureIdentifier = try DefaultDeviceIdentifier(configuration: .highSecurity)
        
        // When
        let id = try await secureIdentifier.id
        
        // Then
        XCTAssertEqual(id.count, 64, "Should generate SHA-256 hash")
        XCTAssertNotNil(id, "Should successfully generate with 4096-bit keys")
    }
    
    func testEncryptionConfiguration_DisabledEncryption() async throws {
        // Given
        let config = DeviceIdentifierConfiguration(
            keySize: 2048,
            keychainAccount: "com.test.noencryption",
            useEncryption: false
        )
        
        // When
        let identifier = try DefaultDeviceIdentifier(configuration: config)
        let id = try await identifier.id
        
        // Then
        XCTAssertNotNil(id, "Should work without encryption")
        XCTAssertEqual(id.count, 64)
    }
    
    func testCustomStorage_UsesProvidedStorage() async throws {
        // Given
        let mockStorage = MockStorage<DeviceIdentifierImpl>()
        
        // When
        let identifier = try DefaultDeviceIdentifier(
            configuration: .default,
            storage: mockStorage
        )
        let id = try await identifier.id
        
        // Then
        XCTAssertTrue(mockStorage.saveCalled, "Should use custom storage")
        XCTAssertEqual(id.count, 64)
    }
}

// MARK: - Mock Storage

private actor MockStorage<T: Codable & Sendable>: Storage {
    var saveCalled = false
    var getCalled = false
    var deleteCalled = false
    private var stored: T?
    
    func save(item: T) async throws {
        saveCalled = true
        stored = item
    }
    
    func get() async throws -> T? {
        getCalled = true
        return stored
    }
    
    func delete() async throws {
        deleteCalled = true
        stored = nil
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}