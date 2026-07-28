//
//  KeychainStorageTests.swift
//  StorageTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class KeychainStorageTests: XCTestCase {
    private var keychainStorage: KeychainStorage<TestItem>!

    // The account and service match exactly what KeychainStorage uses internally.
    private let account = "testAccount"
    private let service = "com.pingidentity.keychainService"

    override func setUp() {
        super.setUp()
        // By default the KeychainStorage does not use encryption
        keychainStorage = KeychainStorage(account: account)
    }

    override func tearDown()  async throws {
        // Clean up any keychain item regardless of accessibility attribute so subsequent
        // tests always start from a clean slate.
        let cleanupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        SecItemDelete(cleanupQuery as CFDictionary)
        keychainStorage = nil
        try await super.tearDown()
    }

    // TestRailCase(24703)
    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    // TestRailCase(24704)
    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    // TestRailCase(24705)
    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        try await keychainStorage.delete()
        let retrievedItem = try await keychainStorage.get()
        XCTAssertNil(retrievedItem)
    }

    // SDKS-5172 — verify saved items carry device-only accessibility
    func testSavedItemHasDeviceOnlyAccessibility() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        let attrs = result as? [String: Any]
        let accessible = attrs?[kSecAttrAccessible as String] as? String
        XCTAssertEqual(accessible, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    // SDKS-5172 — verify upgrade path: item stored with old accessibility is replaced cleanly
    func testUpgradePathDoesNotThrowDuplicateItem() async throws {
        // Pre-populate keychain with old-style accessibility (simulating a token stored
        // by an earlier SDK version that used kSecAttrAccessibleWhenUnlocked by default).
        let oldData = try JSONEncoder().encode(TestItem(id: 99, name: "OldToken"))
        let oldQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: oldData
        ]
        let insertStatus = SecItemAdd(oldQuery as CFDictionary, nil)
        XCTAssertEqual(insertStatus, errSecSuccess, "Pre-condition: old item should insert cleanly")

        // Save via SDK — should delete the old item and add a new one without throwing.
        let newItem = TestItem(id: 1, name: "NewToken")
        do {
            try await keychainStorage.save(item: newItem)
        } catch {
            XCTFail("save() should not throw when replacing an item with mismatched accessibility: \(error)")
        }

        // Verify the new item carries device-only accessibility.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        let attrs = result as? [String: Any]
        let accessible = attrs?[kSecAttrAccessible as String] as? String
        XCTAssertEqual(accessible, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    // SDKS-5172 — verify the existing token survives a failed save() (encryption error).
    // save() must encrypt BEFORE deleting the previous item, so a transient encrypt failure
    // never leaves the keychain slot empty (data-loss regression guard).
    func testExistingTokenSurvivesFailedSave() async throws {
        // First, store a good token using a non-throwing encryptor.
        let goodStorage = KeychainStorage<TestItem>(account: account)
        let original = TestItem(id: 1, name: "Original")
        try await goodStorage.save(item: original)

        // Now attempt to save a new token through an encryptor that always fails.
        let failingStorage = KeychainStorage<TestItem>(account: account, encryptor: FailingEncryptor())
        do {
            try await failingStorage.save(item: TestItem(id: 2, name: "New"))
            XCTFail("save() should throw when encryption fails")
        } catch {
            // Expected — encryption failed.
        }

        // The original token must still be retrievable (it was never deleted).
        let retrieved = try await goodStorage.get()
        XCTAssertEqual(retrieved, original, "Existing token must survive a failed save()")
    }
}

/// An `Encryptor` that always throws on encrypt — used to verify save() does not destroy the
/// existing keychain item when encryption fails.
private struct FailingEncryptor: Encryptor {
    func encrypt(data: Data) async throws -> Data {
        throw EncryptorError.failedToEncrypt
    }

    func decrypt(data: Data) async throws -> Data {
        throw EncryptorError.failedToDecrypt
    }
}
