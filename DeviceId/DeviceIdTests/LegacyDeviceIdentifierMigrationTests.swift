//
//  LegacyDeviceIdentifierMigrationTests.swift
//  DeviceIdTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceId
import PingStorage

/// Tests for legacy device identifier migration functionality.
/// These tests verify that legacy identifiers from FRAuth SDK are properly detected,
/// migrated, and used instead of generating new identifiers.
final class LegacyDeviceIdentifierMigrationTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        // Clean up before each test
        cleanupKeychain()
    }
    
    override func tearDownWithError() throws {
        // Clean up after each test
        cleanupKeychain()
    }
    
    private func cleanupKeychain() {
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            async let defaultCleanup: Void = {
                try? await DefaultDeviceIdentifier(configuration: .default).keychainService.delete()
            }()
            
            async let legacyCleanup: Void = {
                await LegacyDeviceIdentifierMigrationTests.deleteLegacyKeychainItem(account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier)
                await LegacyDeviceIdentifierMigrationTests.deleteLegacyKeychainItem(account: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData)
                await LegacyDeviceIdentifierMigrationTests.deleteLegacyKeychainItem(account: LegacyDeviceIdentifier.LegacyKeychainKeys.privateKeyData)
            }()
            
            async let systemKeychainCleanup: Void = {
                await LegacyDeviceIdentifierMigrationTests.deleteLegacySystemKeychainKeys()
            }()
            
            await defaultCleanup
            await legacyCleanup
            await systemKeychainCleanup
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    /// Helper to delete legacy system keychain keys (RSA keys stored with kSecClassKey)
    private static func deleteLegacySystemKeychainKeys() async {
        let publicKeyTag = "com.forgerock.ios.device-identifier.public-key".data(using: .utf8)!
        let privateKeyTag = "com.forgerock.ios.device-identifier.private-key".data(using: .utf8)!
        
        // Delete public key
        let publicKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag
        ]
        SecItemDelete(publicKeyQuery as CFDictionary)
        
        // Delete private key
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag
        ]
        SecItemDelete(privateKeyQuery as CFDictionary)
    }
    
    /// Helper to delete legacy keychain items using raw Security framework
    private static func deleteLegacyKeychainItem(account: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    /// Helper to save legacy keychain item using raw Security framework (simulating FRAuth SDK)
    private func saveLegacyKeychainItem(account: String, value: String) async throws {
        try await Task.detached {
            guard let data = value.data(using: .utf8) else {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode string"])
            }
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            // Delete first to ensure clean state
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(deleteQuery as CFDictionary)
            
            // Add the item
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save to keychain"])
            }
        }.value
    }
    
    /// Helper to save legacy public key data using raw Security framework
    private func saveLegacyPublicKeyData(_ data: Data) async throws {
        try await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            // Delete first to ensure clean state
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData
            ]
            SecItemDelete(deleteQuery as CFDictionary)
            
            // Add the item
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save public key to keychain"])
            }
        }.value
    }
    
    // MARK: - Legacy Identifier Migration Tests
    
    /// Test that when a legacy identifier exists, it is retrieved and used instead of generating a new one
    func testLegacyIdentifierIsUsedWhenAvailable() async throws {
        // GIVEN: A legacy identifier exists in keychain (using raw keychain like FRAuth SDK would)
        let expectedLegacyId = "abc123def456legacy789"
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: expectedLegacyId
        )
        
        // WHEN: Creating a new DefaultDeviceIdentifier
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let actualId = try await deviceIdentifier.id
        
        // THEN: The returned identifier should match the legacy one
        XCTAssertEqual(actualId, expectedLegacyId, "Should use legacy identifier instead of generating new one")
        
        // AND: The identifier should be stable across multiple calls
        let secondCallId = try await deviceIdentifier.id
        XCTAssertEqual(actualId, secondCallId, "Legacy identifier should be stable")
        
        // AND: A new instance should also use the same legacy identifier
        let newInstance = try DefaultDeviceIdentifier()
        let newInstanceId = try await newInstance.id
        XCTAssertEqual(actualId, newInstanceId, "New instance should also use migrated legacy identifier")
    }
    
    /// Test that legacy identifier stored in new format persists correctly
    func testLegacyIdentifierPersistedInNewFormat() async throws {
        // GIVEN: A legacy identifier exists (using raw keychain like FRAuth SDK would)
        let expectedLegacyId = "legacy_identifier_12345"
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: expectedLegacyId
        )
        
        // WHEN: First access triggers migration
        let firstIdentifier = try DefaultDeviceIdentifier()
        let migratedId = try await firstIdentifier.id
        
        // THEN: The migrated ID should match the legacy one
        XCTAssertEqual(migratedId, expectedLegacyId)
        
        // WHEN: We clear the legacy storage (simulating it being removed)
        await LegacyDeviceIdentifierMigrationTests.deleteLegacyKeychainItem(account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier)
        
        // AND: Create a new instance
        let secondIdentifier = try DefaultDeviceIdentifier()
        let persistedId = try await secondIdentifier.id
        
        // THEN: The identifier should still be the legacy one (now persisted in new format)
        XCTAssertEqual(persistedId, expectedLegacyId, "Legacy identifier should persist in new format even after legacy storage is cleared")
    }
    
    /// Test that when no legacy identifier exists, a new one is generated
    func testNewIdentifierGeneratedWhenNoLegacyExists() async throws {
        // GIVEN: No legacy identifier exists (clean keychain)
        
        // WHEN: Creating a new DefaultDeviceIdentifier
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let generatedId = try await deviceIdentifier.id
        
        // THEN: A new identifier should be generated (SHA-256 hash = 64 chars)
        XCTAssertEqual(generatedId.count, 64, "Should generate new SHA-256 based identifier")
        XCTAssertFalse(generatedId.isEmpty)
        
        // AND: It should be stable
        let secondCallId = try await deviceIdentifier.id
        XCTAssertEqual(generatedId, secondCallId)
    }
    
    /// Test migration from public key when identifier doesn't exist but public key SecKey does
    func testMigrationFromLegacyPublicKey() async throws {
        // GIVEN: A legacy RSA public key exists in system keychain (simulating FRAuth SDK)
        // We need to create a real RSA key pair and store it with the legacy application tag
        let publicKeyTag = "com.forgerock.ios.device-identifier.public-key".data(using: .utf8)!
        
        // Clean up any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Generate a test RSA key pair (matching FRAuth SDK behavior)
        let attributes: CFDictionary = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPublicKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: publicKeyTag
            ] as CFDictionary
        ] as CFDictionary
        
        var publicKey: SecKey?
        var privateKey: SecKey?
        let status = SecKeyGeneratePair(attributes, &publicKey, &privateKey)
        
        guard status == errSecSuccess, let pubKey = publicKey else {
            XCTFail("Failed to generate test RSA key pair. Status: \(status)")
            return
        }
        
        // WHEN: Creating a DefaultDeviceIdentifier (should find the legacy key)
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let migratedId = try await deviceIdentifier.id
        
        // THEN: An identifier should be generated from the legacy public key
        XCTAssertFalse(migratedId.isEmpty, "Should generate identifier from legacy public key")
        // Legacy migration uses SHA-1 hash with hex encoding (40 characters)
        XCTAssertEqual(migratedId.count, 40, "Legacy identifier from public key should be SHA-1 hex encoded (40 chars)")
        
        // AND: The same identifier should be returned on subsequent calls
        let secondCallId = try await deviceIdentifier.id
        XCTAssertEqual(migratedId, secondCallId, "Migrated identifier should be stable")
        
        // AND: A new instance should return the same migrated identifier
        let newInstance = try DefaultDeviceIdentifier()
        let newInstanceId = try await newInstance.id
        XCTAssertEqual(migratedId, newInstanceId, "Migrated identifier should persist")
        
        // Clean up the test key
        SecItemDelete(deleteQuery as CFDictionary)
    }
    
    /// Test that regenerateIdentifier works correctly even with legacy migration
    func testRegenerateIdentifierAfterLegacyMigration() async throws {
        // GIVEN: A legacy identifier that has been migrated (using raw keychain like FRAuth SDK would)
        let legacyId = "legacy_identifier_xyz"
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: legacyId
        )
        
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let initialId = try await deviceIdentifier.id
        XCTAssertEqual(initialId, legacyId)
        
        // WHEN: Regenerating the identifier
        let regeneratedId = try await deviceIdentifier.regenerateIdentifier()
        
        // THEN: A new identifier should be generated (different from legacy)
        XCTAssertNotEqual(regeneratedId, legacyId, "Regenerated identifier should be different from legacy")
        XCTAssertEqual(regeneratedId.count, 64, "Regenerated identifier should be SHA-256 based")
        
        // AND: The new identifier should be stable
        let afterRegenerationId = try await deviceIdentifier.id
        XCTAssertEqual(regeneratedId, afterRegenerationId)
    }
    
    /// Test concurrent access during legacy migration
    func testConcurrentAccessDuringLegacyMigration() async throws {
        // GIVEN: A legacy identifier exists (using raw keychain like FRAuth SDK would)
        let legacyId = "concurrent_legacy_test"
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: legacyId
        )
        
        // WHEN: Multiple concurrent requests are made
        let deviceIdentifier = try DefaultDeviceIdentifier()
        
        let ids = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await deviceIdentifier.id }
            }
            var results = [String]()
            for try await id in group {
                results.append(id)
            }
            return results
        }
        
        // THEN: All should return the same legacy identifier
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 1, "All concurrent calls should return same legacy identifier")
        XCTAssertEqual(uniqueIds.first, legacyId, "Concurrent calls should all get the legacy identifier")
    }
    
    /// Test that cache clearing works correctly with legacy identifiers
    func testCacheClearingWithLegacyIdentifier() async throws {
        // GIVEN: A legacy identifier that has been loaded (using raw keychain like FRAuth SDK would)
        let legacyId = "cache_test_legacy_id"
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: legacyId
        )
        
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let firstId = try await deviceIdentifier.id
        XCTAssertEqual(firstId, legacyId)
        
        // WHEN: Clearing the cache
        await deviceIdentifier.clearCache()
        
        // THEN: The identifier should still be the same (loaded from storage)
        let afterClearId = try await deviceIdentifier.id
        XCTAssertEqual(afterClearId, legacyId, "Should reload legacy identifier from storage after cache clear")
    }
    
    // MARK: - Tests with Mock Storage
    
    /// Test legacy migration with custom mock storage
    func testLegacyMigrationWithMockStorage() async throws {
        // GIVEN: A mock storage implementation
        let mockStorage = MockStorage<DeviceIdentifierImpl>()
        let deviceIdentifier = DefaultDeviceIdentifier(
            configuration: .default,
            storage: mockStorage,
            logger: nil
        )
        
        // WHEN: Initially there's no data
        let newId = try await deviceIdentifier.id
        
        // THEN: A new identifier is generated
        XCTAssertEqual(newId.count, 64, "Should generate new identifier with empty mock storage")
        
        // WHEN: We manually save a legacy identifier to storage
        let legacyId = "mock_legacy_identifier"
        let emptyKeyPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
        let legacyImpl = DeviceIdentifierImpl(deviceIdentifierKeyPair: emptyKeyPair, legacyIdentifier: legacyId)
        try await mockStorage.save(item: legacyImpl)
        
        // AND: Clear cache and access again
        await deviceIdentifier.clearCache()
        let retrievedId = try await deviceIdentifier.id
        
        // THEN: The legacy identifier should be returned
        XCTAssertEqual(retrievedId, legacyId, "Should retrieve legacy identifier from mock storage")
    }
    
    /// Test that DeviceIdentifierImpl correctly returns legacy identifier when present
    func testDeviceIdentifierImplWithLegacyIdentifier() async throws {
        // GIVEN: A DeviceIdentifierImpl with a legacy identifier
        let legacyId = "test_legacy_id_123"
        let emptyKeyPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
        let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: emptyKeyPair, legacyIdentifier: legacyId)
        
        // WHEN: Accessing the id
        let retrievedId = try await impl.id
        
        // THEN: The legacy identifier should be returned, not a computed one
        XCTAssertEqual(retrievedId, legacyId, "DeviceIdentifierImpl should return legacy identifier when present")
    }
    
    /// Test that DeviceIdentifierImpl computes hash when no legacy identifier
    func testDeviceIdentifierImplWithoutLegacyIdentifier() async throws {
        // GIVEN: A DeviceIdentifierImpl without a legacy identifier
        let publicKeyData = Data("sample_public_key".utf8)
        let keyPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: publicKeyData)
        let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: keyPair)
        
        // WHEN: Accessing the id
        let retrievedId = try await impl.id
        
        // THEN: The identifier should be a SHA-256 hash (64 characters)
        XCTAssertEqual(retrievedId.count, 64, "Should compute SHA-256 hash when no legacy identifier")
        XCTAssertFalse(retrievedId.isEmpty)
    }
    
    /// Test migration priority: direct identifier > public key regeneration > new generation
    func testMigrationPriority() async throws {
        // GIVEN: Both legacy identifier AND public key exist (using raw keychain like FRAuth SDK would)
        let directLegacyId = "direct_legacy_identifier"
        let publicKeyData = Data("legacy_public_key".utf8)
        
        try await saveLegacyKeychainItem(
            account: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            value: directLegacyId
        )
        try await saveLegacyPublicKeyData(publicKeyData)
        
        // WHEN: Creating a DefaultDeviceIdentifier
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let retrievedId = try await deviceIdentifier.id
        
        // THEN: The direct legacy identifier should be used (higher priority)
        XCTAssertEqual(retrievedId, directLegacyId, "Direct legacy identifier should take priority over public key regeneration")
    }
    
    /// Test that legacy identifier is properly encoded/decoded
    func testLegacyIdentifierCodable() async throws {
        // GIVEN: A DeviceIdentifierImpl with legacy identifier
        let legacyId = "codable_test_legacy"
        let keyPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
        let originalImpl = DeviceIdentifierImpl(deviceIdentifierKeyPair: keyPair, legacyIdentifier: legacyId)
        
        // WHEN: Encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(originalImpl)
        let decoded = try decoder.decode(DeviceIdentifierImpl.self, from: encoded)
        
        // THEN: The legacy identifier should be preserved
        let decodedId = try await decoded.id
        XCTAssertEqual(decodedId, legacyId, "Legacy identifier should survive encoding/decoding")
    }
    
    /// Test that the hashing format matches FRAuth SDK (SHA-1 + hex encoding)
    func testLegacyHashingFormatIsHexNotBase64() async throws {
        // GIVEN: A legacy RSA public key exists in system keychain
        let publicKeyTag = "com.forgerock.ios.device-identifier.public-key".data(using: .utf8)!
        
        // Clean up any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Generate a test RSA key pair
        let attributes: CFDictionary = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPublicKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: publicKeyTag
            ] as CFDictionary
        ] as CFDictionary
        
        var publicKey: SecKey?
        var privateKey: SecKey?
        let status = SecKeyGeneratePair(attributes, &publicKey, &privateKey)
        
        guard status == errSecSuccess else {
            XCTFail("Failed to generate test RSA key pair")
            return
        }
        
        // WHEN: Migrating the identifier
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let migratedId = try await deviceIdentifier.id
        
        // THEN: The identifier should be hex-encoded (only 0-9, a-f)
        let isHexOnly = migratedId.allSatisfy { "0123456789abcdefABCDEF".contains($0) }
        XCTAssertTrue(isHexOnly, "Legacy identifier should use hex encoding (only 0-9, a-f)")
        
        // AND: Should be 40 characters (SHA-1 hash in hex)
        XCTAssertEqual(migratedId.count, 40, "Legacy identifier should be SHA-1 hex (40 characters)")
        
        // AND: Should NOT contain base64-specific characters like +, /, =
        XCTAssertFalse(migratedId.contains("+"), "Should not contain base64 character '+'")
        XCTAssertFalse(migratedId.contains("/"), "Should not contain base64 character '/'")
        XCTAssertFalse(migratedId.contains("="), "Should not contain base64 character '='")
        
        // Clean up
        SecItemDelete(deleteQuery as CFDictionary)
    }
}

actor Mock<T: Codable & Sendable>: Storage {
    private var data: T?
    
    public func save(item: T) async throws {
        data = item
    }
    
    public func get() async throws -> T?  {
        return data
    }
    
    public func delete() async throws {
        data = nil
    }
}

class MockStorage<T: Codable& Sendable>: StorageDelegate<T>, @unchecked Sendable {
    public init(cacheable: Bool = false) {
        super.init(delegate: Mock<T>(), cacheable: cacheable)
    }
}
