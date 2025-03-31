//
//  StorageDelegate.swift
//  PingStorage
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage delegate class that delegates its operations to a storage.
/// It can optionally cache the stored item in memory.
/// This class is designed to be subclassed by specific storage strategies (e.g., keychain, in-memory) that conform to the `Storage` protocol.
///
/// - Parameter T: The type of the object being stored. Must conform to `Codable` to ensure that
///                object can be easily encoded and decoded.
open class StorageDelegate<T: Codable & Sendable>: Storage, @unchecked Sendable {
    private let delegate: any Storage<T>
    private let cacheable: Bool
    private let cacheManager = CacheManager<T>()
    
    /// Initializer for StorageDelegate
    /// - Parameters:
    ///   - delegate: The storage to delegate the operations to.
    ///   - cacheable: Whether the storage delegate should cache the object in memory.
    public init(delegate: any Storage<T>, cacheable: Bool = false) {
        self.delegate = delegate
        self.cacheable = cacheable
    }
    
    /// Saves the given item in the storage and optionally in memory.
    /// - Parameter item: The item to save.
    public func save(item: T) async throws {
        try await delegate.save(item: item)
        
        if cacheable {
            await cacheManager.setCache(item)
        }
    }
    
    /// Retrieves the item from memory if it's cached, otherwise from the storage.
    /// - Returns: The item if it exists, `nil` otherwise.
    public func get() async throws -> T? {
        if cacheable, let cachedItem = await cacheManager.getCache() {
            return cachedItem
        }
        
        return try await delegate.get()
    }
    
    /// Deletes the item from the storage and removes it from memory if it's cached.
    public func delete() async throws {
        try await delegate.delete()
        
        if cacheable {
            await cacheManager.clearCache()
        }
    }
}

/// An actor that manages the cache of a specific type.
private actor CacheManager<T> {
    private var cached: T?
    
    func getCache() -> T? {
        return cached
    }
    
    func setCache(_ value: T) {
        cached = value
    }
    
    func clearCache() {
        cached = nil
    }
}
