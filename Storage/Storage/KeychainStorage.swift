//
//  KeychainStorage.swift
//  PingStorage
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage for storing `Codable` objects in the Keychain
public actor Keychain<T: Codable & Sendable>: Storage {
    private let account: String
    private let service: String = "com.pingidentity.keychainService"
    private let encryptor: Encryptor
    
    /// Initializer for Keychain
    /// - Parameters:
    ///   - account: String indicating the item's account(key) name.
    ///   - encryptor: Encryptor for encrypting stored data. Default value is `NoEncryptor()`
    public init(account: String, encryptor: Encryptor = NoEncryptor()) {
        self.account = account
        self.encryptor = encryptor
    }
    
    /// Saves the given item in the keychain.
    /// - Parameter item: The item to save.
    public func save(item: T) async throws {
        let data = try JSONEncoder().encode(item)

        // Encrypt BEFORE deleting the existing item. If encryption fails (e.g. the Secure
        // Enclave key is transiently unavailable under device lock or memory pressure), this
        // throws here and the previously stored token is left untouched — never leaving the
        // keychain slot empty.
        let encrypted = try await encryptor.encrypt(data: data)

        // Delete using primary key only (class + account + service) — no accessibility filter
        // so ANY pre-existing item is removed regardless of its stored accessibility class.
        // This prevents errSecDuplicateItem when upgrading from an older SDK version that
        // stored items with the default kSecAttrAccessibleWhenUnlocked accessibility.
        let deleteQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ] as [String: Any]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the fresh item with device-only accessibility to prevent iCloud/iTunes backup
        // migration. kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly is chosen over
        // kSecAttrAccessibleWhenUnlockedThisDeviceOnly to allow background token refresh
        // (Background App Refresh, silent push) after first device unlock, matching the
        // accessibility used by SecuredKey for SE-backed keys.
        let addQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: encrypted
        ] as [String: Any]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }
    
    /// Retrieves the item from the keychain.
    /// - Returns: The item if it exists, `nil` otherwise.
    public func get() async throws -> T? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue!
        ] as [String: Any]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        return try JSONDecoder().decode(T.self, from: try await encryptor.decrypt(data: data))
    }
    
    /// Deletes the item from memory.
    public func delete() async throws {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unableToDelete
        }
    }
}


/// `KeychainError` represents errors that can occur while interacting with the keychain.
public enum KeychainError: LocalizedError, Sendable {
    case unableToSave
    case unableToRetrieve
    case unableToDelete
    
    /// A localized message describing what error occurred.
    public var errorMessage: String {
        switch self {
        case .unableToSave:
            return "Unable to save to the keychain"
        case .unableToRetrieve:
            return "Unable to retrieve from the keychain"
        case .unableToDelete:
            return "Unable to delete from the keychain"
        }
    }

    /// A localized description of the error, used by `LocalizedError`.
    public var errorDescription: String? { errorMessage }
}


/// `KeychainStorage` is a generic class that conforms to the `StorageDelegate` protocol, providing a secure storage solution by leveraging the keychain.
/// It is designed to store, retrieve, and manage objects of type `T`, where `T` must conform to the `Codable` protocol. This requirement ensures that the objects can be easily encoded and decoded for secure storage in the keychain.
///
/// - Parameter T: The type of the objects to be stored in the keychain. Must conform to `Codable`.
public class KeychainStorage<T: Codable & Sendable>: StorageDelegate<T>, @unchecked Sendable {
    /// Initializes a new instance of `KeychainStorage`.
    ///
    /// This initializer configures a `KeychainStorage` instance with a specified account and security settings.
    /// It allows storing data securely in the keychain using the provided account identifier. T
    ///
    /// - Parameters:
    ///   - account: A `String` identifying the keychain account under which the data will be stored. This is used
    ///              to differentiate between different sets of data within the keychain.
    ///   - encryptor: An `Encryptor` instance for encrypting/decrypting the stored data. Default value is `NoEncryptor()`
    ///   - cacheStrategy: A CacheStrategy `ENUM` indicating whether the stored data should be cached. Defaults to `NO_CACHE`.
    public init(account: String, encryptor: Encryptor = NoEncryptor(), cacheStrategy: CacheStrategy = .NO_CACHE) {
        super.init(delegate: Keychain<T>(account: account, encryptor: encryptor), cacheStrategy: cacheStrategy)
    }
}
