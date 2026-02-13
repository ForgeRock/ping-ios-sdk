# StorageDelegate Caching System - Complete Guide

## Table of Contents

1. [Overview](#overview)
2. [Cache Strategies](#cache-strategies)
3. [Architecture](#architecture)
4. [Implementation Details](#implementation-details)
5. [Usage Examples](#usage-examples)
6. [Best Practices](#best-practices)
7. [Migration Guide](#migration-guide)
8. [Performance Characteristics](#performance-characteristics)
9. [Thread Safety](#thread-safety)
10. [Testing](#testing)

---

## Overview

The `StorageDelegate` caching system provides a flexible, thread-safe layer for managing in-memory caches across various storage implementations. It supports three distinct caching strategies, each optimized for different use cases.

### Key Features

- ✅ **Multiple Strategies**: Choose between NO_CACHE, CACHE, and CACHE_ON_FAILURE
- ✅ **Thread-Safe**: Built on Swift actors for safe concurrent access
- ✅ **Type-Safe**: Full generic support with Codable and Sendable constraints
- ✅ **Flexible**: Works with any Storage implementation (Memory, Keychain, custom)
- ✅ **Resilient**: CACHE_ON_FAILURE strategy provides graceful degradation
- ✅ **Well-Tested**: Comprehensive test suite with 25+ test cases

---

## Cache Strategies

### 1. NO_CACHE (Default)

**When to use:** You always need fresh data and memory usage is a concern.

```swift
let storage = StorageDelegate(
    delegate: KeychainStorage(account: "user.settings"),
    cacheStrategy: .NO_CACHE
)
```

**Behavior:**
- ❌ No caching layer
- ✅ All operations go directly to storage
- ✅ Always fresh data
- ✅ Minimal memory footprint

**Flow Diagram:**
```
save(item) → storage.save(item)
get()      → storage.get()
delete()   → storage.delete()
```

**Use Cases:**
- User preferences that may change externally
- Frequently changing data
- Memory-constrained environments
- Debugging/development

---

### 2. CACHE

**When to use:** Performance is critical and you can tolerate cache-storage inconsistencies.

```swift
let storage = StorageDelegate(
    delegate: RemoteStorage(endpoint: "api/config"),
    cacheStrategy: .CACHE
)
```

**Behavior:**
- ✅ Cache populated on save
- ✅ Reads served from cache (fast)
- ⚠️ On save failure, item remains cached
- ✅ Falls back to storage if cache empty

**Flow Diagram:**
```
save(item) → cache.set(item) → storage.save(item)
           ↓ (on failure)
           cache still has item

get()      → cache.get()
           ↓ (if nil)
           storage.get()

delete()   → storage.delete() → cache.clear()
```

**Use Cases:**
- App configuration
- Static content
- Frequently read, rarely written data
- Performance-critical paths

---

### 3. CACHE_ON_FAILURE

**When to use:** You need resilience against intermittent failures.

```swift
let storage = StorageDelegate(
    delegate: NetworkKeychain(account: "auth.token"),
    cacheStrategy: .CACHE_ON_FAILURE
)
```

**Behavior:**
- ✅ Storage operations attempted first
- ✅ Successful gets populate cache
- ✅ Cache used as fallback on failures
- ✅ Prefers fresh data

**Flow Diagram:**
```
save(item) → storage.save(item)
           ↓ (on success)
           cache.clear()
           ↓ (on failure)
           cache.set(item) → throw error

get()      → storage.get()
           ↓ (on success)
           cache.set(item) → return item
           ↓ (on failure)
           cache.get() or throw error

delete()   → storage.delete() → cache.clear()
```

**Use Cases:**
- Network storage
- Remote APIs
- Intermittent connectivity scenarios
- Authentication tokens
- Critical user data

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────┐
│         Your Application                │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│       StorageDelegate<T>                │
│  ┌─────────────────────────────────┐   │
│  │   CacheStrategy Logic           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────┐    ┌──────────────┐  │
│  │ CacheManager│    │   Delegate   │  │
│  │   (Actor)   │    │   Storage    │  │
│  └─────────────┘    └──────────────┘  │
└─────────────────────────────────────────┘
         │                     │
         ▼                     ▼
   In-Memory Cache      Underlying Storage
   (Optional)           (Memory, Keychain, etc.)
```

### Class Hierarchy

```
Storage Protocol
    │
    ├── Memory<T> (Actor)
    │
    ├── Keychain<T> (Actor)
    │
    └── StorageDelegate<T> (Class)
            │
            ├── MemoryStorage<T>
            ├── KeychainStorage<T>
            └── (Custom Storage Types)
```

---

## Implementation Details

### CacheManager Actor

```swift
private actor CacheManager<T> {
    private var cached: T?
    
    func getCache() -> T?
    func setCache(_ value: T)
    func clearCache()
}
```

**Purpose:** Provides thread-safe cache operations through actor isolation.

**Lifecycle:**
- Created once per StorageDelegate instance
- Lives for the lifetime of the StorageDelegate
- Automatically serializes all cache operations

### Save Operation Internals

#### NO_CACHE
```swift
case .NO_CACHE:
    try await delegate.save(item: item)
```

#### CACHE
```swift
case .CACHE:
    await cacheManager.setCache(item)      // Cache first
    do {
        try await delegate.save(item: item) // Then save
    } catch {
        // Item already cached
        throw error
    }
```

#### CACHE_ON_FAILURE
```swift
case .CACHE_ON_FAILURE:
    do {
        try await delegate.save(item: item)  // Save first
        await cacheManager.clearCache()      // Clear cache on success
    } catch {
        await cacheManager.setCache(item)    // Cache on failure
        throw error
    }
```

### Get Operation Internals

#### NO_CACHE
```swift
case .NO_CACHE:
    return try await delegate.get()
```

#### CACHE
```swift
case .CACHE:
    if let cachedItem = await cacheManager.getCache() {
        return cachedItem               // Return cached
    }
    return try await delegate.get()     // Fallback to storage
```

#### CACHE_ON_FAILURE
```swift
case .CACHE_ON_FAILURE:
    do {
        let item = try await delegate.get()
        if let item = item {
            await cacheManager.setCache(item)  // Cache successful get
        }
        return item
    } catch {
        if let cachedItem = await cacheManager.getCache() {
            return cachedItem                   // Fallback to cache
        }
        throw error
    }
```

---

## Usage Examples

### Example 1: App Configuration (CACHE)

```swift
struct AppConfig: Codable, Sendable {
    let apiEndpoint: String
    let featureFlags: [String: Bool]
    let refreshInterval: TimeInterval
}

class ConfigurationManager {
    private let storage = StorageDelegate(
        delegate: KeychainStorage(account: "app.config"),
        cacheStrategy: .CACHE
    )
    
    func loadConfig() async throws -> AppConfig {
        // First call: fetches from keychain
        // Subsequent calls: served from cache (fast!)
        return try await storage.get() ?? defaultConfig
    }
    
    func updateConfig(_ config: AppConfig) async throws {
        // Caches immediately, then persists
        try await storage.save(item: config)
    }
}
```

### Example 2: Network Authentication (CACHE_ON_FAILURE)

```swift
struct AuthToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

class AuthManager {
    private let storage = StorageDelegate(
        delegate: NetworkKeychain(account: "auth.token"),
        cacheStrategy: .CACHE_ON_FAILURE
    )
    
    func getToken() async throws -> AuthToken? {
        do {
            // Try to get fresh token from network
            let token = try await storage.get()
            print("✅ Fresh token retrieved")
            return token
        } catch {
            // Network failed, but cache might have it
            print("⚠️ Using cached token (network unavailable)")
            return try await storage.get() // Returns cached token
        }
    }
    
    func saveToken(_ token: AuthToken) async throws {
        do {
            try await storage.save(item: token)
            print("✅ Token saved and cached")
        } catch {
            print("⚠️ Network save failed, but token cached for offline use")
            throw error
        }
    }
}
```

### Example 3: Session Data (NO_CACHE)

```swift
struct UserSession: Codable, Sendable {
    let userId: String
    let sessionId: String
    let lastActivity: Date
}

class SessionManager {
    private let storage = StorageDelegate(
        delegate: Memory<UserSession>(),
        cacheStrategy: .NO_CACHE  // Always fresh session data
    )
    
    func startSession(for userId: String) async throws {
        let session = UserSession(
            userId: userId,
            sessionId: UUID().uuidString,
            lastActivity: Date()
        )
        try await storage.save(item: session)
    }
    
    func getCurrentSession() async throws -> UserSession? {
        // Always gets current session state
        return try await storage.get()
    }
    
    func updateActivity() async throws {
        guard var session = try await storage.get() else { return }
        session.lastActivity = Date()
        try await storage.save(item: session)
    }
    
    func endSession() async throws {
        try await storage.delete()
    }
}
```

### Example 4: Multi-Strategy System

```swift
class DataManager {
    // Static config: cached for performance
    private let configStorage = StorageDelegate(
        delegate: KeychainStorage(account: "config"),
        cacheStrategy: .CACHE
    )
    
    // User data: resilient against network failures
    private let userStorage = StorageDelegate(
        delegate: NetworkKeychain(account: "user.profile"),
        cacheStrategy: .CACHE_ON_FAILURE
    )
    
    // Temporary data: no caching needed
    private let tempStorage = StorageDelegate(
        delegate: Memory<TempData>(),
        cacheStrategy: .NO_CACHE
    )
    
    func initializeApp() async throws {
        // Fast config load from cache
        let config = try await configStorage.get()
        
        // User data with fallback
        let user = try await userStorage.get()
        
        // Fresh temp data
        let temp = try await tempStorage.get()
    }
}
```

---

## Best Practices

### 1. Choose the Right Strategy

✅ **DO:**
```swift
// Network storage - use CACHE_ON_FAILURE
let networkData = StorageDelegate(
    delegate: NetworkKeychain(...),
    cacheStrategy: .CACHE_ON_FAILURE
)

// Static config - use CACHE
let config = StorageDelegate(
    delegate: KeychainStorage(...),
    cacheStrategy: .CACHE
)

// Frequently changing data - use NO_CACHE
let liveData = StorageDelegate(
    delegate: Memory<LiveData>(),
    cacheStrategy: .NO_CACHE
)
```

❌ **DON'T:**
```swift
// Don't cache memory storage in production
let redundantCache = MemoryStorage<Data>(cacheStrategy: .CACHE)

// Don't use NO_CACHE for expensive network calls
let slowNetwork = StorageDelegate(
    delegate: ExpensiveNetworkStorage(...),
    cacheStrategy: .NO_CACHE  // Will be slow!
)
```

### 2. Handle Errors Appropriately

✅ **DO:**
```swift
func loadData() async -> Data? {
    do {
        return try await storage.get()
    } catch {
        logger.error("Storage error: \(error)")
        return nil  // Or show user-friendly message
    }
}
```

❌ **DON'T:**
```swift
func loadData() async -> Data? {
    try! await storage.get()  // Never use try! with storage
}
```

### 3. Test Cache Behavior

```swift
final class CacheTests: XCTestCase {
    func testCacheOnFailureResilience() async throws {
        let storage = FailingStorage<Token>()
        let delegate = StorageDelegate(
            delegate: storage,
            cacheStrategy: .CACHE_ON_FAILURE
        )
        
        // Save fails but caches
        do {
            try await delegate.save(item: token)
        } catch {
            // Expected
        }
        
        // Get still returns cached token
        let cached = try await delegate.get()
        XCTAssertEqual(cached, token)
    }
}
```

### 4. Document Strategy Choice

```swift
class UserManager {
    /// User profile storage with CACHE_ON_FAILURE strategy.
    /// This provides offline access to the last successfully
    /// retrieved profile when the network is unavailable.
    private let profileStorage = StorageDelegate(
        delegate: NetworkKeychain(account: "user.profile"),
        cacheStrategy: .CACHE_ON_FAILURE
    )
}
```

---

## Migration Guide

### From Boolean `cacheable` to `CacheStrategy`

#### Before (Deprecated):
```swift
let storage1 = StorageDelegate(delegate: Memory<User>(), cacheable: true)
let storage2 = StorageDelegate(delegate: Memory<User>(), cacheable: false)
let storage3 = MemoryStorage<User>(cacheable: true)
```

#### After:
```swift
let storage1 = StorageDelegate(delegate: Memory<User>(), cacheStrategy: .CACHE)
let storage2 = StorageDelegate(delegate: Memory<User>(), cacheStrategy: .NO_CACHE)
let storage3 = MemoryStorage<User>(cacheStrategy: .CACHE)
```

### Mapping:
- `cacheable: true` → `cacheStrategy: .CACHE`
- `cacheable: false` → `cacheStrategy: .NO_CACHE`
- New option → `cacheStrategy: .CACHE_ON_FAILURE`

---

## Performance Characteristics

### Operation Complexity

| Strategy          | Save       | Get (Cached) | Get (Uncached) | Delete     | Memory    |
|-------------------|------------|--------------|----------------|------------|-----------|
| NO_CACHE          | O(s)       | O(s)         | O(s)           | O(s)       | O(1)      |
| CACHE             | O(s)       | O(1)         | O(s)           | O(s)       | O(n)      |
| CACHE_ON_FAILURE  | O(s)       | O(s)         | O(s)           | O(s)       | O(n)      |

*s = storage operation time, n = size of cached item*

### Benchmark Results (Example)

```swift
// NO_CACHE: 1000 gets
Avg: 0.05ms per operation
Total: 50ms

// CACHE: 1000 gets (all cached)
Avg: 0.001ms per operation
Total: 1ms (50x faster!)

// CACHE_ON_FAILURE: 1000 gets (storage available)
Avg: 0.05ms per operation
Total: 50ms (same as NO_CACHE)

// CACHE_ON_FAILURE: 1000 gets (storage failing, cache hit)
Avg: 0.001ms per operation
Total: 1ms (provides fallback performance)
```

### Memory Usage

```swift
// NO_CACHE
Memory: sizeof(StorageDelegate) ≈ 64 bytes

// CACHE
Memory: sizeof(StorageDelegate) + sizeof(T) ≈ 64 + sizeof(T) bytes

// CACHE_ON_FAILURE
Memory: sizeof(StorageDelegate) + sizeof(T) ≈ 64 + sizeof(T) bytes
```

---

## Thread Safety

### Actor-Based Concurrency

All cache operations are serialized through the `CacheManager` actor:

```swift
// 100 concurrent reads - all safe!
await withTaskGroup(of: User?.self) { group in
    for _ in 0..<100 {
        group.addTask {
            try? await storage.get()
        }
    }
}

// Concurrent reads and writes - safe!
async let user1 = storage.get()
async let user2 = storage.get()
async let saveResult = storage.save(item: newUser)

let (u1, u2, _) = await (user1, user2, saveResult)
```

### Race Condition Handling

The actor model prevents data races:

```swift
// Thread A
await cacheManager.setCache(userA)

// Thread B (concurrent)
await cacheManager.setCache(userB)

// One will win, data won't be corrupted
// Both operations are atomic
```

---

## Testing

### Test Coverage

The test suite includes:

1. **Basic Operations**: save, get, delete for all strategies
2. **Cache Behavior**: cache hits, misses, fallbacks
3. **Failure Scenarios**: storage failures, cache fallbacks
4. **Concurrency**: concurrent access, race conditions
5. **Edge Cases**: nil values, empty cache, repeated operations
6. **Deprecated API**: backward compatibility

### Running Tests

```bash
# Run all storage tests
xcodebuild test -scheme PingStorage -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -scheme PingStorage -only-testing:StorageDelegateTests

# Run specific cache strategy tests
xcodebuild test -scheme PingStorage -only-testing:StorageDelegateCacheStrategyTests
```

### Writing Custom Tests

```swift
import Testing
@testable import PingStorage

@Suite("Custom Cache Tests")
struct CustomCacheTests {
    
    @Test("CACHE strategy serves from cache")
    func cacheStrategyReadsFromCache() async throws {
        let mock = MockStorage<String>()
        let delegate = StorageDelegate(
            delegate: mock,
            cacheStrategy: .CACHE
        )
        
        try await delegate.save(item: "test")
        
        // First get
        _ = try await delegate.get()
        #expect(mock.getCallCount == 0, "Should read from cache")
        
        // Second get
        _ = try await delegate.get()
        #expect(mock.getCallCount == 0, "Should still read from cache")
    }
}
```

---

## Additional Resources

- [StorageDelegate API Documentation](StorageDelegate.swift)
- [CacheStrategy Enum](StorageDelegate.swift#CacheStrategy)
- [MemoryStorage Implementation](MemoryStorage.swift)
- [Test Suite](StorageDelegateTests.swift)
- [Storage Protocol](Storage.swift)

---

## FAQ

**Q: Should I use CACHE with MemoryStorage?**  
A: Generally no. Since Memory is already in RAM, adding another cache layer just adds overhead. Use `.NO_CACHE` (default) for production.

**Q: What happens if save fails with CACHE strategy?**  
A: The item remains in cache. This means subsequent `get()` calls return the cached item even though it wasn't persisted.

**Q: How do I clear the cache manually?**  
A: Call `delete()` on the storage. This clears both storage and cache.

**Q: Can I use different strategies for the same storage?**  
A: Yes! Create multiple StorageDelegate instances with different strategies wrapping the same underlying storage.

**Q: Is CACHE_ON_FAILURE suitable for critical data?**  
A: Yes, but be aware you might get stale data during failures. Implement proper error handling and user notifications.

**Q: How long does cached data persist?**  
A: Cache persists for the lifetime of the StorageDelegate instance. It's cleared on `delete()` or when the instance is deallocated.

---

*Last Updated: February 13, 2026*
