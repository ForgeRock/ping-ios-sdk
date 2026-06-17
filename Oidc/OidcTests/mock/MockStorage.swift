//
//  MockStorage.swift
//  OidcTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingStorage

public actor Mock<T: Codable & Sendable>: Storage {
    private var data: T?

    public func save(item: T) async throws {
        data = item
    }

    public func get() async throws -> T?  {
        return data
    }

    public func delete() async throws {
        data = nil
    }
}

public class MockStorage<T: Codable& Sendable>: StorageDelegate<T>, @unchecked Sendable {
    public init(cacheStrategy: CacheStrategy = .NO_CACHE) {
        super.init(delegate: Mock<T>(), cacheStrategy: cacheStrategy)
    }
}

// MARK: - ThrowingMock

/// A simple error used to simulate a transient (non-`EncryptorError`) storage failure.
public enum TransientStorageError: Error, Sendable {
    case interactionNotAllowed
}

/// A configurable actor-based Storage that can simulate decryption and delete failures.
/// Used to test recovery paths where a cached token is unreadable (e.g. after device migration)
/// and the negative paths where the failure is transient or `delete()` itself fails.
public actor ThrowingMock<T: Codable & Sendable>: Storage {
    private var data: T?

    /// When `true`, `get()` throws `getError` to simulate a failure reading the cached token.
    public var throwOnGet: Bool = false

    /// The error thrown by `get()` when `throwOnGet` is `true`. Defaults to a decryption failure,
    /// matching the Secure Enclave key-mismatch scenario after device migration.
    public var getError: Error = EncryptorError.failedToDecrypt

    /// When `true`, `delete()` throws `KeychainError.unableToDelete` to simulate a keychain that
    /// cannot clear the corrupted item (e.g. errSecInteractionNotAllowed while the device is locked).
    public var throwOnDelete: Bool = false

    /// Set to `true` when `delete()` is called; allows test assertions on cleanup behaviour.
    public var deleteWasCalled: Bool = false

    public func save(item: T) async throws {
        data = item
    }

    public func get() async throws -> T? {
        if throwOnGet {
            throw getError
        }
        return data
    }

    public func delete() async throws {
        deleteWasCalled = true
        if throwOnDelete {
            throw KeychainError.unableToDelete
        }
        throwOnGet = false
        data = nil
    }

    /// Convenience setter so tests can configure `throwOnGet` from outside the actor.
    public func set(throwOnGet value: Bool) {
        throwOnGet = value
    }

    /// Convenience setter so tests can configure `throwOnDelete` from outside the actor.
    public func set(throwOnDelete value: Bool) {
        throwOnDelete = value
    }

    /// Convenience setter so tests can configure the error thrown by `get()`.
    public func set(getError value: Error) {
        getError = value
    }
}

/// `ThrowingMockStorage` wraps `ThrowingMock` inside a `StorageDelegate` using `.NO_CACHE`,
/// mirroring the shape of `MockStorage`. Exposes the underlying `ThrowingMock` so tests can
/// inspect `deleteWasCalled` and toggle `throwOnGet`.
public class ThrowingMockStorage<T: Codable & Sendable>: StorageDelegate<T>, @unchecked Sendable {
    /// The underlying actor; use `await throwingMock.<property>` to read test state.
    public let throwingMock: ThrowingMock<T>

    public init() {
        let mock = ThrowingMock<T>()
        self.throwingMock = mock
        super.init(delegate: mock, cacheStrategy: .NO_CACHE)
    }
}

