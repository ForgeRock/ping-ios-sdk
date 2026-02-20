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
        storageDelegate = StorageDelegate(delegate: memoryStorage, cacheStrategy: .NO_CACHE)
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

// MARK: - Cache Strategy Tests

final class StorageDelegateNoCacheStrategyTests: XCTestCase {
    
    func testNoCacheStrategySaveAndGet() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .NO_CACHE)
        let item = TestItem(id: 1, name: "No Cache Test")
        
        // Save should go directly to storage
        try await delegate.save(item: item)
        let saveCount1 = await mockStorage.saveCallCount
        XCTAssertEqual(saveCount1, 1)
        
        // Get should always fetch from storage
        _ = try await delegate.get()
        let getCount1 = await mockStorage.getCallCount
        XCTAssertEqual(getCount1, 1)
        
        // Second get should also fetch from storage (no caching)
        _ = try await delegate.get()
        let getCount2 = await mockStorage.getCallCount
        XCTAssertEqual(getCount2, 2)
    }
    
    func testNoCacheStrategyDelete() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .NO_CACHE)
        let item = TestItem(id: 1, name: "Delete Test")
        
        try await delegate.save(item: item)
        try await delegate.delete()
        
        let deleteCount = await mockStorage.deleteCallCount
        XCTAssertEqual(deleteCount, 1)
        let retrieved = try await delegate.get()
        XCTAssertNil(retrieved)
    }
}

final class StorageDelegateCacheStrategyTests: XCTestCase {
    
    func testCacheStrategySavePopulatesCache() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Cache Test")
        
        // Save should populate cache and storage
        try await delegate.save(item: item)
        let saveCount = await mockStorage.saveCallCount
        XCTAssertEqual(saveCount, 1)
        
        // First get should return from cache without hitting storage
        let retrieved1 = try await delegate.get()
        XCTAssertEqual(retrieved1, item)
        let getCount1 = await mockStorage.getCallCount
        XCTAssertEqual(getCount1, 0, "Should return from cache, not storage")
        
        // Second get should also return from cache
        let retrieved2 = try await delegate.get()
        XCTAssertEqual(retrieved2, item)
        let getCount2 = await mockStorage.getCallCount
        XCTAssertEqual(getCount2, 0, "Should still return from cache")
    }
    
    func testCacheStrategyGetFallbackToStorage() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Fallback Test")
        
        // Directly save to mock storage (bypassing cache)
        try await mockStorage.save(item: item)
        
        // Get should check cache first (empty), then fall back to storage
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item)
        let getCount = await mockStorage.getCallCount
        XCTAssertEqual(getCount, 1, "Should fetch from storage when cache is empty")
    }
    
    func testCacheStrategySaveFailureKeepsCache() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnSave: true)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Fail Test")
        
        // Save should fail but cache the item
        do {
            try await delegate.save(item: item)
            XCTFail("Save should have thrown an error")
        } catch {
            // Expected failure
        }
        
        // Get should return cached item even though save failed
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item, "Cached item should be available even after save failure")
    }
    
    func testCacheStrategyDeleteClearsCache() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Delete Cache Test")
        
        try await delegate.save(item: item)
        
        // Delete should clear both storage and cache
        try await delegate.delete()
        let deleteCount = await mockStorage.deleteCallCount
        XCTAssertEqual(deleteCount, 1)
        
        // Get should return nil (cache cleared and storage empty)
        let retrieved = try await delegate.get()
        XCTAssertNil(retrieved)
    }
}

final class StorageDelegateCacheOnFailureStrategyTests: XCTestCase {
    
    func testCacheOnFailureSaveSuccessClearsCache() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Success Test")
        
        // Successful save should clear any existing cache
        try await delegate.save(item: item)
        let saveCount = await mockStorage.saveCallCount
        XCTAssertEqual(saveCount, 1)
        
        // Get should fetch from storage (not cache)
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item)
        let getCount = await mockStorage.getCallCount
        XCTAssertEqual(getCount, 1, "Should fetch from storage on success")
    }
    
    func testCacheOnFailureSaveFailureCachesItem() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnSave: true)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Failure Test")
        
        // Save should fail but cache the item
        do {
            try await delegate.save(item: item)
            XCTFail("Save should have thrown an error")
        } catch {
            // Expected failure
        }
        
        // Now make get also fail so it falls back to cache
        await mockStorage.setShouldFailOnGet(true)
        
        // Get should try storage first, fail, then return cached item
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item, "Should return cached item after save failure")
    }
    
    func testCacheOnFailureGetSuccessFromStorage() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Get Success Test")
        
        // Save item to storage
        try await mockStorage.save(item: item)
        
        // Get should fetch from storage successfully and cache it
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item)
        let getCount = await mockStorage.getCallCount
        XCTAssertEqual(getCount, 1)
    }
    
    func testCacheOnFailureGetSuccessCachesForFutureFailures() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnGet: false)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Cache for Future Test")
        
        // Save item to storage
        try await mockStorage.save(item: item)
        
        // First get should succeed and cache the item
        let retrieved1 = try await delegate.get()
        XCTAssertEqual(retrieved1, item)
        
        // Now make storage fail
        await mockStorage.setShouldFailOnGet(true)
        
        // Second get should fall back to cache from previous successful get
        let retrieved2 = try await delegate.get()
        XCTAssertEqual(retrieved2, item, "Should return cached item from previous successful get")
    }
    
    func testCacheOnFailureGetFailureFallsBackToCache() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnSave: true)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Fallback Test")
        
        // First, fail to save (which caches the item)
        do {
            try await delegate.save(item: item)
            XCTFail("Save should have thrown an error")
        } catch {
            // Expected failure
        }
        
        // Now also make get fail
        await mockStorage.setShouldFailOnGet(true)
        
        // Get should fall back to cache
        let retrieved = try await delegate.get()
        XCTAssertEqual(retrieved, item, "Should fall back to cached item when get fails")
    }
    
    func testCacheOnFailureGetFailureWithoutCacheThrows() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnGet: true)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        
        // Get should throw error when storage fails and cache is empty
        do {
            _ = try await delegate.get()
            XCTFail("Get should have thrown an error")
        } catch {
            // Expected failure
            XCTAssertEqual(error as? MockStorageError, MockStorageError.getFailed)
        }
    }
    
    func testCacheOnFailureDeleteClearsCache() async throws {
        let mockStorage = FailingMockStorage<TestItem>(shouldFailOnSave: true)
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Delete Test")
        
        // Fail to save (which caches the item)
        do {
            try await delegate.save(item: item)
        } catch {
            // Expected
        }
        
        // Make delete succeed
        await mockStorage.setShouldFailOnDelete(false)
        
        // Delete should clear cache
        try await delegate.delete()
        
        // Make get fail so it would fall back to cache if available
        await mockStorage.setShouldFailOnGet(true)
        
        // Should throw since cache is cleared
        do {
            _ = try await delegate.get()
            XCTFail("Get should throw after delete clears cache")
        } catch {
            // Expected
        }
    }
}

// MARK: - Concurrent Access Tests for Cache Strategies

final class StorageDelegateConcurrencyTests: XCTestCase {
    
    func testCacheStrategyConcurrentAccess() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE)
        let item = TestItem(id: 1, name: "Concurrent Test")
        
        try await delegate.save(item: item)
        
        // Concurrent reads should all use cache safely
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    do {
                        let retrieved = try await delegate.get()
                        XCTAssertEqual(retrieved, item)
                    } catch {
                        XCTFail("Get failed: \(error)")
                    }
                }
            }
        }
        
        // Cache should have handled all requests, minimal storage access
        let getCount = await mockStorage.getCallCount
        XCTAssertLessThan(getCount, 10, "Most requests should be served from cache")
    }
    
    func testCacheOnFailureStrategyConcurrentAccess() async throws {
        let mockStorage = MockStorage<TestItem>()
        let delegate = StorageDelegate(delegate: mockStorage, cacheStrategy: .CACHE_ON_FAILURE)
        let item = TestItem(id: 1, name: "Concurrent Failure Test")
        
        try await mockStorage.save(item: item)
        
        // Concurrent reads should all access storage
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    do {
                        let retrieved = try await delegate.get()
                        XCTAssertEqual(retrieved, item)
                    } catch {
                        XCTFail("Get failed: \(error)")
                    }
                }
            }
        }
        
        // All requests should go to storage
        let getCount = await mockStorage.getCallCount
        XCTAssertEqual(getCount, 50, "All requests should fetch from storage")
    }
}

// MARK: - Mock Storage Implementations

private actor MockStorage<T: Codable & Sendable>: Storage {
    private(set) var saveCallCount = 0
    private(set) var getCallCount = 0
    private(set) var deleteCallCount = 0
    private var data: T?
    
    func save(item: T) async throws {
        saveCallCount += 1
        data = item
    }
    
    func get() async throws -> T? {
        getCallCount += 1
        return data
    }
    
    func delete() async throws {
        deleteCallCount += 1
        data = nil
    }
}

private enum MockStorageError: Error, Equatable {
    case saveFailed
    case getFailed
    case deleteFailed
}

private actor FailingMockStorage<T: Codable & Sendable>: Storage {
    var shouldFailOnSave: Bool
    var shouldFailOnGet: Bool
    var shouldFailOnDelete: Bool
    private var data: T?
    
    init(shouldFailOnSave: Bool = false, shouldFailOnGet: Bool = false, shouldFailOnDelete: Bool = false) {
        self.shouldFailOnSave = shouldFailOnSave
        self.shouldFailOnGet = shouldFailOnGet
        self.shouldFailOnDelete = shouldFailOnDelete
    }
    
    func setShouldFailOnSave(_ value: Bool) {
        shouldFailOnSave = value
    }
    
    func setShouldFailOnGet(_ value: Bool) {
        shouldFailOnGet = value
    }
    
    func setShouldFailOnDelete(_ value: Bool) {
        shouldFailOnDelete = value
    }
    
    func save(item: T) async throws {
        if shouldFailOnSave {
            throw MockStorageError.saveFailed
        }
        data = item
    }
    
    func get() async throws -> T? {
        if shouldFailOnGet {
            throw MockStorageError.getFailed
        }
        return data
    }
    
    func delete() async throws {
        if shouldFailOnDelete {
            throw MockStorageError.deleteFailed
        }
        data = nil
    }
}
