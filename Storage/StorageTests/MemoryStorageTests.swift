//
//  MemoryStorageTests.swift
//  StorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class MemoryStorageTests: XCTestCase {
    private var memoryStorage: MemoryStorage<TestItem>!
    private var memoryStorageMulti: MemoryStorage<Array<TestItem>>!
    
    override func setUp() {
        super.setUp()
        memoryStorage = MemoryStorage()
        memoryStorageMulti = MemoryStorage()
    }
    
    override func tearDown() {
        memoryStorage = nil
        memoryStorageMulti = nil
        super.tearDown()
    }
    
    // TestRailCase(21622)
    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        let retrievedItem = try await memoryStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    // TestRailCase(21623)
    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        let retrievedItem = try await memoryStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    // TestRailCase(21626)
    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        try await memoryStorage.delete()
        let retrievedItem = try await memoryStorage.get()
        XCTAssertNil(retrievedItem)
    }

    // TestRailCase(21624, 21625)
    func testMultipleData() async throws {
        var itemsArray = [TestItem]()
        let item1 = TestItem(id: 1, name: "Test1")
        let item2 = TestItem(id: 2, name: "Test2")
        
        itemsArray.append(item1)
        itemsArray.append(item2)
        
        // Save in memory storage
        try await memoryStorageMulti.save(item: itemsArray)
        
        // Restore from memory storage
        let retrievedItem = try await memoryStorageMulti.get()
        
        XCTAssertEqual(retrievedItem, itemsArray)
        XCTAssertEqual(retrievedItem![0], item1)
        XCTAssertEqual(retrievedItem![1], item2)
    }
}

struct TestItem: Codable, Equatable {
    let id: Int
    let name: String
}
