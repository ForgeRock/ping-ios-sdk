//
//  KeychainStorageTests.swift
//  StorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class KeychainStorageTests: XCTestCase {
    private var keychainStorage: KeychainStorage<TestItem>!

    override func setUp() {
        super.setUp()
        // By default the KeychainStorage does not use encryption
        keychainStorage = KeychainStorage(account: "testAccount")
    }

    override func tearDown() {
      Task {
        try? await keychainStorage.delete()
        keychainStorage = nil
      }
      super.tearDown()
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
}
