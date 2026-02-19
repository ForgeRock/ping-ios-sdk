//
//  StorageAdditionalTests.swift
//  StorageTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingStorage


// MARK: - MemoryStorage Caching Tests

final class MemoryStorageCachingTests: XCTestCase {
    
    func testMemoryStorageWithCacheEnabled() async throws {
        let storage = MemoryStorage<TestItem>(cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Cached Item")
        
        try await storage.save(item: item)
        let retrieved = try await storage.get()
        
        XCTAssertEqual(retrieved, item)
    }
    
    func testMemoryStorageWithCacheDisabled() async throws {
        let storage = MemoryStorage<TestItem>(cacheStrategy: .NO_CACHE)
        let item = TestItem(id: 2, name: "Non-Cached Item")
        
        try await storage.save(item: item)
        let retrieved = try await storage.get()
        
        XCTAssertEqual(retrieved, item)
    }
}

// MARK: - KeychainStorage Caching Tests

final class KeychainStorageCachingTests: XCTestCase {
    
    var keychainStorage: KeychainStorage<TestItem>!
    
    override func setUp() {
        super.setUp()
        keychainStorage = KeychainStorage(account: "testCacheAccount", cacheStrategy: .CACHE)
    }
    
    override func tearDown() async throws {
        try? await keychainStorage.delete()
        keychainStorage = nil
        try await super.tearDown()
    }
    
    func testKeychainStorageWithCacheEnabled() async throws {
        let item = TestItem(id: 1, name: "Cached Keychain Item")
        
        try await keychainStorage.save(item: item)
        let retrieved = try await keychainStorage.get()
        
        XCTAssertEqual(retrieved, item)
    }
}

// MARK: - SecuredKey Availability Tests

final class SecuredKeyAvailabilityTests: XCTestCase {
    
    func testIsAvailable() {
        // Just verify the static method exists and returns a boolean
        let isAvailable = SecuredKey.isAvailable()
        // On simulator this will be false, on device it could be true
        XCTAssertNotNil(isAvailable)
    }
}

// MARK: - Memory Actor Tests

final class MemoryActorTests: XCTestCase {
    
    func testMemoryActorSaveAndGet() async throws {
        let memory = Memory<TestItem>()
        let item = TestItem(id: 1, name: "Actor Test")
        
        try await memory.save(item: item)
        let retrieved = try await memory.get()
        
        XCTAssertEqual(retrieved, item)
    }
    
    func testMemoryActorDelete() async throws {
        let memory = Memory<TestItem>()
        let item = TestItem(id: 1, name: "Actor Delete Test")
        
        try await memory.save(item: item)
        try await memory.delete()
        let retrieved = try await memory.get()
        
        XCTAssertNil(retrieved)
    }
    
    func testMemoryActorGetReturnsNilWhenEmpty() async throws {
        let memory = Memory<TestItem>()
        let retrieved = try await memory.get()
        XCTAssertNil(retrieved)
    }
}

// MARK: - Keychain Actor Tests

final class KeychainActorTests: XCTestCase {
    
    var keychain: Keychain<TestItem>!
    
    override func setUp() {
        super.setUp()
        keychain = Keychain(account: "testActorAccount")
    }
    
    override func tearDown() async throws {
        try? await keychain.delete()
        keychain = nil
        try await super.tearDown()
    }
    
    func testKeychainActorWithCustomEncryptor() async throws {
        let customEncryptor = CustomEncryptor()
        let keychainWithEncryptor = Keychain<TestItem>(account: "testEncryptorAccount", encryptor: customEncryptor)
        let item = TestItem(id: 1, name: "Encrypted Item")
        
        try await keychainWithEncryptor.save(item: item)
        let retrieved = try await keychainWithEncryptor.get()
        
        XCTAssertEqual(retrieved, item)
        
        try? await keychainWithEncryptor.delete()
    }
    
    func testKeychainActorGetReturnsNilWhenEmpty() async throws {
        let emptyKeychain = Keychain<TestItem>(account: "emptyTestAccount")
        let retrieved = try await emptyKeychain.get()
        XCTAssertNil(retrieved)
    }
}

// MARK: - StorageDelegate Caching Tests

final class StorageDelegateCachingTests: XCTestCase {
    
    func testStorageDelegateWithCacheEnabled() async throws {
        let memory = Memory<TestItem>()
        let delegate = StorageDelegate<TestItem>(delegate: memory, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Cached Delegate Item")
        
        try await delegate.save(item: item)
        
        // First get should populate cache
        let firstGet = try await delegate.get()
        XCTAssertEqual(firstGet, item)
        
        // Second get should return from cache
        let secondGet = try await delegate.get()
        XCTAssertEqual(secondGet, item)
    }
    
    func testStorageDelegateDeleteClearsCache() async throws {
        let memory = Memory<TestItem>()
        let delegate = StorageDelegate<TestItem>(delegate: memory, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Delete Cache Item")
        
        try await delegate.save(item: item)
        try await delegate.delete()
        
        let retrieved = try await delegate.get()
        XCTAssertNil(retrieved)
    }
}
