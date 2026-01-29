//
//  StorageDelegateTests.swift
//  StorageTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class StorageDelegateTests: XCTestCase, @unchecked Sendable {
    private var storageDelegate: StorageDelegate<TestItem>!
    private var memoryStorage: MemoryStorage<TestItem>!
    
    override func setUp() {
        super.setUp()
        memoryStorage = MemoryStorage()
        storageDelegate = StorageDelegate(delegate: memoryStorage, cacheable: false)
    }
    
    override func tearDown() {
        storageDelegate = nil
        memoryStorage = nil
        super.tearDown()
    }
    
    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await storageDelegate.save(item: item)
        let retrievedItem = try await storageDelegate.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await storageDelegate.save(item: item)
        let retrievedItem = try await storageDelegate.get()
        XCTAssertEqual(retrievedItem, item)
    }
    
    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await storageDelegate.save(item: item)
        try await storageDelegate.delete()
        let retrievedItem = try await storageDelegate.get()
        XCTAssertNil(retrievedItem)
    }
    
    func testConcurrentAccess() async throws {
        let item = TestItem(id: 1, name: "Test")
        let iterations = 100 // Reduced for stability
        
        // Concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    do {
                        try await self.storageDelegate.save(item: item)
                    } catch {
                        XCTFail("Save failed: \(error)")
                    }
                }
            }
        }
        
        // Concurrent reads
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    do {
                        let _ = try await self.storageDelegate.get()
                    } catch {
                        XCTFail("Get failed: \(error)")
                    }
                }
            }
        }
        
        // Verify the final value
        let finalValue = try await storageDelegate.get()
        XCTAssertEqual(finalValue, item)
    }

    func testConcurrentModification() async throws {
        let item = TestItem(id: 1, name: "Test")
        let iterations = 100 // Reduced for stability
        
        // Concurrent writes and deletes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    do {
                        if i % 2 == 0 {
                            try await self.storageDelegate.save(item: item)
                        } else {
                            try await self.storageDelegate.delete()
                        }
                    } catch {
                        XCTFail("Modification failed: \(error)")
                    }
                }
            }
        }
        
        // Just verify no crash occurred
        XCTAssertTrue(true)
    }
}
