//
//  EncryptedKeychainStorageTests.swift
//  StorageTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class EncryptedKeychainStorageTests: XCTestCase {
    private var keychainStorage: KeychainStorage<TestItem>!
    
    override func setUp() {
        super.setUp()
        // Test KeychainStorage with the SecuredKeyEncryptor - the OOTB encryptor provided by the SDK
        keychainStorage = KeychainStorage(account: "testAccount", encryptor: SecuredKeyEncryptor()!)
    }
    
    override func tearDown() async throws {
        
        try? await keychainStorage.delete()
        keychainStorage = nil
        
        try await super.tearDown()
    }
    
    // TestRailCase(24706)
    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    // TestRailCase(24707)
    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    // TestRailCase(24708)
    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        try await keychainStorage.delete()
        let retrievedItem = try await keychainStorage.get()
        XCTAssertNil(retrievedItem)
    }
}
