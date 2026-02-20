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

/// A storage delegate class that provides flexible caching strategies for storage operations.
///
/// `StorageDelegate` acts as a wrapper around any `Storage` implementation, adding an optional
/// in-memory caching layer. This enables various performance and resilience patterns depending on
/// your application's requirements.
///
/// ## Overview
///
/// The delegate pattern allows you to:
/// - Add caching to any storage implementation without modifying the underlying storage
/// - Choose from multiple caching strategies to match your use case
/// - Maintain thread-safe concurrent access through Swift actors
/// - Provide degraded functionality during storage failures
///
/// ## Caching Strategies
///
/// Three caching strategies are available through the `CacheStrategy` enum:
///
/// ### NO_CACHE (Default)
/// All operations go directly to the underlying storage with no caching layer.
/// ```swift
/// let storage = StorageDelegate(
///     delegate: KeychainStorage(),
///     cacheStrategy: .NO_CACHE
/// )
/// ```
/// **Use when:** You always need fresh data and memory usage is a concern.
///
/// ### CACHE
/// Items are cached in memory on save. Reads are served from cache when available.
/// ```swift
/// let storage = StorageDelegate(
///     delegate: RemoteStorage(),
///     cacheStrategy: .CACHE
/// )
/// ```
/// **Use when:** Performance is critical and you can tolerate cache-storage inconsistencies on failures.
///
/// ### CACHE_ON_FAILURE
/// Items are cached after successful operations. Cache serves as fallback during storage failures.
/// ```swift
/// let storage = StorageDelegate(
///     delegate: NetworkStorage(),
///     cacheStrategy: .CACHE_ON_FAILURE
/// )
/// ```
/// **Use when:** You need resilience against intermittent failures and can tolerate stale data.
///
/// ## Thread Safety
///
/// All caching operations are thread-safe through the use of Swift actors. Multiple concurrent
/// reads and writes are handled safely without the need for external synchronization.
///
/// ## Example Usage
///
/// ```swift
/// // High-performance cached configuration
/// let config = StorageDelegate(
///     delegate: KeychainStorage(account: "app.config"),
///     cacheStrategy: .CACHE
/// )
/// try await config.save(item: appConfig)
/// let cachedConfig = try await config.get() // Served from cache
///
/// // Resilient network storage
/// let userData = StorageDelegate(
///     delegate: NetworkKeychain(account: "user.data"),
///     cacheStrategy: .CACHE_ON_FAILURE
/// )
/// try await userData.save(item: user)
/// // Later, even if network fails...
/// let user = try await userData.get() // Falls back to cache
/// ```
///
/// - Parameter T: The type of the object being stored. Must conform to `Codable` and `Sendable`
///                to ensure safe encoding/decoding and concurrent access.
///
/// - Note: This class is designed to be subclassed by specific storage strategies (e.g., `MemoryStorage`,
///         `KeychainStorage`) that conform to the `Storage` protocol.
///
/// - SeeAlso: `CacheStrategy`, `Storage`, `MemoryStorage`, `KeychainStorage`
open class StorageDelegate<T: Codable & Sendable>: Storage, @unchecked Sendable {
    private let delegate: any Storage<T>
    private let cacheStrategy: CacheStrategy
    private let cacheManager = CacheManager<T>()
    
    /// Initializes a new StorageDelegate with the specified cache strategy.
    ///
    /// This is the preferred initializer for creating storage delegates with caching support.
    /// The cache strategy determines how the in-memory cache interacts with the underlying storage.
    ///
    /// ## Cache Strategy Behavior
    ///
    /// - **NO_CACHE**: No caching layer is used. All operations go directly to the delegate storage.
    /// - **CACHE**: Items are cached on save. Subsequent reads are served from cache, falling back
    ///              to storage only if cache is empty.
    /// - **CACHE_ON_FAILURE**: Items are cached after successful operations. Cache serves as a
    ///                         fallback when storage operations fail, providing resilience.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a resilient network storage with cache fallback
    /// let networkStorage = StorageDelegate(
    ///     delegate: KeychainStorage(account: "user.token"),
    ///     cacheStrategy: .CACHE_ON_FAILURE
    /// )
    ///
    /// // Save succeeds and caches the token
    /// try await networkStorage.save(item: authToken)
    ///
    /// // If keychain becomes unavailable, cache provides fallback
    /// let token = try await networkStorage.get() // Returns cached token
    /// ```
    ///
    /// - Parameters:
    ///   - delegate: The underlying storage to delegate operations to. This can be any type
    ///               conforming to `Storage<T>`, such as `Memory<T>`, `Keychain<T>`, or custom implementations.
    ///   - cacheStrategy: The caching strategy to use. Defaults to `.NO_CACHE` for backward compatibility
    ///                    and minimal memory footprint.
    ///
    /// - SeeAlso: `CacheStrategy`
    public init(delegate: any Storage<T>, cacheStrategy: CacheStrategy = .NO_CACHE) {
        self.delegate = delegate
        self.cacheStrategy = cacheStrategy
    }
    
    /// Saves the given item to storage with cache behavior determined by the cache strategy.
    ///
    /// The save operation behavior varies based on the configured `CacheStrategy`:
    ///
    /// ## Cache Strategy Behavior
    ///
    /// ### NO_CACHE
    /// The item is saved directly to the underlying storage with no caching.
    /// ```swift
    /// try await storage.save(item: user)
    /// // Item saved to storage only
    /// ```
    ///
    /// ### CACHE
    /// The item is cached in memory first, then saved to storage. If the storage save fails,
    /// the item remains in cache, allowing subsequent reads to return the cached value.
    /// ```swift
    /// try await storage.save(item: user)
    /// // Item cached immediately, then saved to storage
    /// // If storage fails, cache still contains the item
    /// ```
    ///
    /// ### CACHE_ON_FAILURE
    /// Attempts to save to storage first. On success, any existing cache is cleared to ensure
    /// fresh reads. On failure, the item is cached to provide a fallback for future operations.
    /// ```swift
    /// try await storage.save(item: user)
    /// // On success: Item saved, cache cleared (prefers fresh data)
    /// // On failure: Item cached, error thrown (provides fallback)
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe and can be called concurrently from multiple tasks.
    /// The underlying cache operations are protected by Swift actors.
    ///
    /// ## Error Handling
    ///
    /// Errors from the underlying storage are propagated to the caller. The cache state
    /// after an error depends on the cache strategy (see above).
    ///
    /// - Parameter item: The item to save. Must conform to `Codable` and `Sendable`.
    /// - Throws: Any error thrown by the underlying storage implementation.
    ///
    /// - SeeAlso: `get()`, `delete()`, `CacheStrategy`
    public func save(item: T) async throws {
        switch cacheStrategy {
        case .CACHE:
            // Cache first, then save to storage
            await cacheManager.setCache(item)
            do {
                try await delegate.save(item: item)
            } catch {
                // Item is already cached, so we keep the cache even on failure
                throw error
            }
            
        case .CACHE_ON_FAILURE:
            // Try to save to storage first
            do {
                try await delegate.save(item: item)
                // If successful, clear any existing cache since we prefer fresh data
                await cacheManager.clearCache()
            } catch {
                // On failure, cache the item so we can retrieve it later
                await cacheManager.setCache(item)
                throw error
            }
            
        case .NO_CACHE:
            // No caching, just save to storage
            try await delegate.save(item: item)
        }
    }
    
    /// Retrieves the stored item with cache behavior determined by the cache strategy.
    ///
    /// The retrieval operation behavior varies based on the configured `CacheStrategy`:
    ///
    /// ## Cache Strategy Behavior
    ///
    /// ### NO_CACHE
    /// Always fetches fresh data directly from the underlying storage. No cache is consulted.
    /// ```swift
    /// let user = try await storage.get()
    /// // Always fetches from storage
    /// ```
    ///
    /// ### CACHE
    /// Checks the cache first. If the cache contains the item, it's returned immediately
    /// without accessing storage. If the cache is empty, the item is fetched from storage
    /// but not cached (cache is only populated on save).
    /// ```swift
    /// let user = try await storage.get()
    /// // First checks cache, falls back to storage if cache is empty
    /// ```
    ///
    /// ### CACHE_ON_FAILURE
    /// Attempts to fetch from storage first. On success, the retrieved item is cached for
    /// future fallback scenarios. On failure, falls back to the cached item if available.
    /// This provides resilience against intermittent storage failures.
    /// ```swift
    /// let user = try await storage.get()
    /// // On success: Returns from storage and caches for future failures
    /// // On failure: Returns cached item if available, otherwise throws error
    /// ```
    ///
    /// ## Null Values
    ///
    /// Returns `nil` if no item is stored and no cached item exists. This is not considered
    /// an error condition.
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe and can be called concurrently from multiple tasks.
    /// The underlying cache operations are protected by Swift actors.
    ///
    /// ## Error Handling
    ///
    /// - For `NO_CACHE` and `CACHE`: Errors from storage are propagated to the caller.
    /// - For `CACHE_ON_FAILURE`: Errors from storage trigger cache fallback. If cache is
    ///   also empty, the storage error is propagated.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // With CACHE_ON_FAILURE strategy
    /// let storage = StorageDelegate(
    ///     delegate: NetworkKeychain(account: "token"),
    ///     cacheStrategy: .CACHE_ON_FAILURE
    /// )
    ///
    /// // First successful get caches the result
    /// let token1 = try await storage.get() // Fetches and caches
    ///
    /// // Later, if storage fails, cache provides fallback
    /// let token2 = try await storage.get() // Returns cached token
    /// ```
    ///
    /// - Returns: The stored item if it exists, `nil` if no item is stored or cached.
    /// - Throws: Any error thrown by the underlying storage, unless using `CACHE_ON_FAILURE`
    ///           strategy with a valid cache.
    ///
    /// - SeeAlso: `save(item:)`, `delete()`, `CacheStrategy`
    public func get() async throws -> T? {
        switch cacheStrategy {
        case .CACHE:
            // Check cache first, then fall back to storage
            if let cachedItem = await cacheManager.getCache() {
                return cachedItem
            }
            return try await delegate.get()
            
        case .CACHE_ON_FAILURE:
            // Try to get from storage first
            do {
                let item = try await delegate.get()
                // Cache successful retrieval for future failures
                if let item = item {
                    await cacheManager.setCache(item)
                }
                return item
            } catch {
                // On failure, fall back to cache
                if let cachedItem = await cacheManager.getCache() {
                    return cachedItem
                }
                throw error
            }
            
        case .NO_CACHE:
            // Always fetch fresh data from storage
            return try await delegate.get()
        }
    }
    
    /// Deletes the stored item from both storage and cache.
    ///
    /// This operation removes the item from the underlying storage and clears any cached
    /// copy, regardless of the cache strategy being used.
    ///
    /// ## Behavior
    ///
    /// 1. Deletes the item from the underlying storage
    /// 2. Clears the cache if any caching strategy is enabled
    ///
    /// Both operations are performed even if one fails, ensuring consistent state.
    ///
    /// ## Cache Strategy Impact
    ///
    /// All cache strategies behave identically for delete operations:
    /// - **NO_CACHE**: Deletes from storage only (no cache to clear)
    /// - **CACHE**: Deletes from storage and clears cache
    /// - **CACHE_ON_FAILURE**: Deletes from storage and clears cache
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe and can be called concurrently from multiple tasks.
    /// The underlying cache operations are protected by Swift actors.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await storage.save(item: user)
    /// let retrieved = try await storage.get() // Returns user (possibly cached)
    ///
    /// try await storage.delete()
    /// let afterDelete = try await storage.get() // Returns nil
    /// ```
    ///
    /// - Throws: Any error thrown by the underlying storage implementation during deletion.
    ///
    /// - Note: After deletion, subsequent `get()` calls will return `nil` until a new item is saved.
    ///
    /// - SeeAlso: `save(item:)`, `get()`
    public func delete() async throws {
        try await delegate.delete()
        
        // Clear cache for all strategies that use caching
        if self.cacheStrategy == .CACHE || self.cacheStrategy == .CACHE_ON_FAILURE {
            await cacheManager.clearCache()
        }
    }
}

/// An actor that manages the in-memory cache for a specific type.
///
/// `CacheManager` provides thread-safe caching operations using Swift's actor isolation.
/// It's used internally by `StorageDelegate` to maintain cached copies of stored items.
///
/// ## Thread Safety
///
/// As an actor, `CacheManager` ensures that all cache operations are thread-safe by
/// serializing access to the cached value. Multiple concurrent tasks can safely call
/// cache methods without external synchronization.
///
/// ## Memory Management
///
/// The cache stores a single optional value in memory. When cleared, the cached value
/// is set to `nil`, making it eligible for garbage collection.
///
/// - Note: This actor is marked `private` as it's an internal implementation detail
///         of the caching mechanism.
private actor CacheManager<T> {
    /// The cached value, if any.
    private var cached: T?
    
    /// Retrieves the currently cached value.
    ///
    /// - Returns: The cached value if one exists, `nil` otherwise.
    func getCache() -> T? {
        return cached
    }
    
    /// Stores a value in the cache.
    ///
    /// This replaces any previously cached value.
    ///
    /// - Parameter value: The value to cache.
    func setCache(_ value: T) {
        cached = value
    }
    
    /// Clears the cache by setting the cached value to `nil`.
    ///
    /// After calling this method, `getCache()` will return `nil` until
    /// `setCache(_:)` is called again.
    func clearCache() {
        cached = nil
    }
}

/// Defines the caching strategy for storage operations.
///
/// The cache strategy determines how `StorageDelegate` manages its in-memory cache
/// in relation to the underlying storage. Each strategy offers different trade-offs
/// between performance, consistency, and resilience.
///
/// ## Available Strategies
///
/// ### CACHE
/// **Priority: Performance**
///
/// Items are cached in memory when saved. Reads are served from cache when available,
/// providing the fastest possible access.
///
/// **Use when:** Performance is critical and you can tolerate cache-storage inconsistencies on save failures.
///
/// ### NO_CACHE
/// **Priority: Consistency**
///
/// No caching layer is used. All operations go directly to the underlying storage,
/// ensuring you always have the most recent data from the source of truth.
///
/// **Use when:** You always need fresh data or memory usage is a concern.
///
/// ### CACHE_ON_FAILURE
/// **Priority: Resilience**
///
/// Cache serves as a fallback mechanism when storage operations fail. On successful
/// operations, fresh data is fetched from storage and cached. Cache is used only when
/// storage is unavailable.
///
/// **Use when:** You need resilience against intermittent failures and can tolerate stale data.
///
/// ## Choosing a Strategy
///
/// Use this decision tree:
///
/// 1. **Is storage reliable and always available?**
///    - Yes → Consider `NO_CACHE` or `CACHE`
///    - No → Use `CACHE_ON_FAILURE`
///
/// 2. **Is read performance critical?**
///    - Yes → Use `CACHE`
///    - No → Consider `NO_CACHE` or `CACHE_ON_FAILURE`
///
/// 3. **Must data always be fresh?**
///    - Yes → Use `NO_CACHE`
///    - No → Use `CACHE` or `CACHE_ON_FAILURE`
///
/// ## Thread Safety
///
/// All cache strategies are thread-safe through Swift actor isolation.
///
/// - SeeAlso: `StorageDelegate`
public enum CacheStrategy {
    /// Always cache items in memory for fast repeated access.
    ///
    /// Reads are served from cache when available. Writes populate both cache and storage.
    /// On save failure, the item remains cached.
    ///
    /// **Best for:** Frequently read data where performance is critical.
    case CACHE
    
    /// Never cache items in memory. All operations go directly to storage.
    ///
    /// Ensures data is always fresh from storage at the cost of performance.
    ///
    /// **Best for:** Data that changes frequently or memory-constrained environments.
    case NO_CACHE
    
    /// Cache items as a fallback for storage failures.
    ///
    /// On successful operations, fresh data is fetched from storage and cached.
    /// Cache serves as a safety net during failures.
    ///
    /// **Best for:** Network storage or scenarios with intermittent failures.
    case CACHE_ON_FAILURE
}

