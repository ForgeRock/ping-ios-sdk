//
//  MemoryStorage.swift
//  PingStorage
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage actor for storing objects in memory.
///
/// `Memory<T>` provides thread-safe in-memory storage using Swift's actor isolation.
/// It's used as the underlying storage for `MemoryStorage` but can also be used directly
/// when you need fine-grained control over storage operations.
///
/// ## Thread Safety
///
/// As an actor, `Memory<T>` ensures all storage operations are thread-safe by serializing
/// access. Multiple concurrent tasks can safely call storage methods without external
/// synchronization.
///
/// ## Persistence
///
/// Data stored in `Memory<T>` exists only in RAM and is lost when the app terminates.
/// For persistent storage, use `Keychain<T>` or other storage implementations.
///
/// ## Example Usage
///
/// ```swift
/// let memory = Memory<User>()
///
/// // Save a user
/// try await memory.save(item: currentUser)
///
/// // Retrieve the user
/// if let user = try await memory.get() {
///     print("Found user: \(user.name)")
/// }
///
/// // Delete the user
/// try await memory.delete()
/// ```
///
/// - Parameter T: The type of the object to be stored. Must conform to `Codable` for
///                serialization and `Sendable` for safe concurrent access.
///
/// - SeeAlso: `MemoryStorage`, `Storage`
public actor Memory<T: Codable & Sendable>: Storage {
    private var data: T?
    
    /// Saves the given item in memory.
    /// - Parameter item: The item to save.
    public func save(item: T) async throws {
        data = item
    }
    
    /// Retrieves the item from memory.
    /// - Returns: The item if it exists, `nil` otherwise.
    public func get() async throws -> T?  {
        return data
    }
    
    /// Deletes the item from memory.
    public func delete() async throws {
        data = nil
    }
}


/// `MemoryStorage` provides an in-memory storage solution with optional caching strategies.
///
/// This class combines the simplicity of in-memory storage with the flexibility of caching
/// strategies. It's built on top of `StorageDelegate` and uses the `Memory<T>` actor for
/// the underlying storage.
///
/// ## Overview
///
/// `MemoryStorage` is ideal for temporary data that doesn't need to persist across app launches.
/// Since the underlying storage is already in memory, the caching layer adds an additional
/// level of indirection that can be useful for specific scenarios.
///
/// ## When to Use Memory Storage
///
/// - **Temporary session data**: User session information that's cleared on logout
/// - **In-flight data**: Data being processed that doesn't need persistence
/// - **Performance testing**: Testing storage patterns without disk I/O overhead
/// - **Cached computations**: Results that can be recomputed if needed
///
/// ## Caching with Memory Storage
///
/// While it may seem redundant to cache in-memory storage, the caching layer can be useful for:
///
/// ### Testing Cache Behavior
/// ```swift
/// // Test how your app handles cache strategies
/// let storage = MemoryStorage<Config>(cacheStrategy: .CACHE_ON_FAILURE)
/// // Simulate failures and verify fallback behavior
/// ```
///
/// ### Consistent API
/// ```swift
/// // Use the same caching API across all storage types
/// let memStorage = MemoryStorage<Token>(cacheStrategy: .CACHE)
/// let keychainStorage = KeychainStorage<Token>(cacheStrategy: .CACHE)
/// // Both support the same operations and strategies
/// ```
///
/// ### Performance Benchmarking
/// ```swift
/// let noCacheStorage = MemoryStorage<Data>(cacheStrategy: .NO_CACHE)
/// let cachedStorage = MemoryStorage<Data>(cacheStrategy: .CACHE)
/// // Compare performance characteristics
/// ```
///
/// ## Typical Usage
///
/// For most use cases with `MemoryStorage`, use `.NO_CACHE` (the default) since the
/// underlying storage is already in memory:
///
/// ```swift
/// // Default: no additional cache layer (recommended)
/// let sessionData = MemoryStorage<Session>()
/// try await sessionData.save(item: currentSession)
/// ```
///
/// ## Migration from Legacy API
///
/// The `cacheable` parameter is removed. Use `cacheStrategy` instead:
///
/// **Before:**
/// ```swift
/// let storage = MemoryStorage<User>(cacheable: true)
/// ```
///
/// **After:**
/// ```swift
/// let storage = MemoryStorage<User>(cacheStrategy: .CACHE)
/// ```
///
/// ## Thread Safety
///
/// All operations are thread-safe through Swift actor isolation. Concurrent access
/// from multiple tasks is handled safely without external synchronization.
///
/// - Parameter T: The type of the objects to be stored. Must conform to `Codable` for
///                serialization and `Sendable` for safe concurrent access.
///
/// - Important: Data stored in `MemoryStorage` is lost when the app terminates.
///              Use `KeychainStorage` or other persistent storage for data that must survive app restarts.
///
/// - SeeAlso: `Memory`, `StorageDelegate`, `CacheStrategy`, `KeychainStorage`
public class MemoryStorage<T: Codable & Sendable>: StorageDelegate<T>, @unchecked Sendable {
    /// Initializes a new instance of `MemoryStorage` with a cache strategy.
    ///
    /// This is the preferred initializer for creating memory storage with caching support.
    ///
    /// ## Cache Strategy Recommendations for Memory Storage
    ///
    /// Since the underlying storage is already in memory, most use cases should use `.NO_CACHE`:
    ///
    /// - **NO_CACHE** (Default, Recommended): Direct access to in-memory storage with minimal overhead
    /// - **CACHE**: Adds an additional cache layer (useful for testing cache behavior)
    /// - **CACHE_ON_FAILURE**: Provides fallback (useful for simulating failure scenarios)
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Default: no additional caching (recommended for production)
    /// let sessionStorage = MemoryStorage<Session>()
    ///
    /// // With explicit NO_CACHE strategy
    /// let tempStorage = MemoryStorage<TempData>(cacheStrategy: .NO_CACHE)
    ///
    /// // For testing cache behavior
    /// let testStorage = MemoryStorage<TestData>(cacheStrategy: .CACHE)
    ///
    /// // For testing failure scenarios
    /// let resilientStorage = MemoryStorage<Config>(cacheStrategy: .CACHE_ON_FAILURE)
    /// ```
    ///
    /// ## Performance Considerations
    ///
    /// - `.NO_CACHE`: Fastest, direct memory access
    /// - `.CACHE`: Adds cache actor overhead (two memory locations)
    /// - `.CACHE_ON_FAILURE`: Adds cache check overhead on every operation
    ///
    /// - Parameter cacheStrategy: The caching strategy to use. Defaults to `.NO_CACHE` for
    ///                            optimal performance with in-memory storage.
    ///
    /// - SeeAlso: `CacheStrategy`, `StorageDelegate`
    public init(cacheStrategy: CacheStrategy = .NO_CACHE) {
        super.init(delegate: Memory<T>(), cacheStrategy: cacheStrategy)
    }
}
