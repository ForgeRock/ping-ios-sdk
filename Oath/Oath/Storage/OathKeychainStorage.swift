//
//  OathKeychainStorage.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import PingLogger

/// Keychain-based storage implementation for OATH credentials.
/// Uses iOS Keychain Services for secure credential storage.
///
/// This implementation stores credential metadata and secrets separately in the iOS Keychain.
/// Credential metadata is stored as JSON data, while secrets are stored as secure keychain items
/// with appropriate accessibility settings.
///
/// - Note: This class is thread-safe and handles concurrent access properly.
public final class OathKeychainStorage: OathStorage, @unchecked Sendable {

    /// The keychain service identifier used for storing credential metadata.
    private let keychainService: String

    /// The keychain service identifier used for storing credential secrets.
    private let keychainSecretService: String

    /// The logger instance for logging storage operations.
    private let logger: Logger?

    /// Security options for keychain operations.
    private let securityOptions: OathKeychainSecurityOptions

    /// Queue for serializing keychain operations to ensure thread safety.
    private let keychainQueue = DispatchQueue(label: "com.pingidentity.oath.keychain", qos: .userInitiated)

    
    // MARK: - Initializers

    /// Creates a new keychain storage instance.
    /// - Parameters:
    ///   - service: The keychain service identifier. Defaults to "com.pingidentity.oath".
    ///   - logger: Optional logger for storage operations.
    ///   - securityOptions: Security configuration for keychain operations. Defaults to standard security.
    public init(
        service: String = "com.pingidentity.oath",
        logger: Logger? = nil,
        securityOptions: OathKeychainSecurityOptions = .standard
    ) {
        self.keychainService = service
        self.keychainSecretService = "\(service).secrets"
        self.logger = logger
        self.securityOptions = securityOptions
    }

    /// Creates a new keychain storage instance with individual security parameters (convenience).
    /// - Parameters:
    ///   - service: The keychain service identifier. Defaults to "com.pingidentity.oath".
    ///   - logger: Optional logger for storage operations.
    ///   - accessGroup: Optional keychain access group for shared access.
    ///   - accessibility: Keychain accessibility level. Defaults to kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
    public convenience init(
        service: String = "com.pingidentity.oath",
        logger: Logger? = nil,
        accessGroup: String? = nil,
        accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ) {
        let securityOptions = OathKeychainSecurityOptions(
            accessibility: accessibility,
            accessGroup: accessGroup
        )
        self.init(service: service, logger: logger, securityOptions: securityOptions)
    }

    
    // MARK: - OathStorage Implementation

    /// Store an OATH credential in the keychain.
    /// - Parameter credential: The OATH credential to store.
    /// - Throws: `OathStorageError.storageFailure` if keychain operations fail.
    public func storeOathCredential(_ credential: OathCredential) async throws {
        logger?.d("Storing OATH credential with ID: \(credential.id)")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            keychainQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Storage instance deallocated"))
                        return
                    }

                    // Store credential metadata (without secret)
                    let credentialData = try JSONEncoder().encode(credential)
                    try self.storeKeychainItem(
                        service: self.keychainService,
                        account: credential.id,
                        data: credentialData
                    )

                    // Store secret separately
                    let secretData = Data(credential.secret.utf8)
                    try self.storeKeychainItem(
                        service: self.keychainSecretService,
                        account: credential.id,
                        data: secretData
                    )

                    self.logger?.d("Successfully stored OATH credential with ID: \(credential.id)")
                    continuation.resume()
                } catch {
                    self?.logger?.e("Failed to store OATH credential with ID \(credential.id): \(error)", error: error)
                    if let storageError = error as? OathStorageError {
                        continuation.resume(throwing: storageError)
                    } else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Failed to store credential", error))
                    }
                }
            }
        }
    }

    /// Retrieve an OATH credential from the keychain.
    /// - Parameter credentialId: The ID of the credential to retrieve.
    /// - Returns: The credential if found, nil otherwise.
    /// - Throws: `OathStorageError.storageFailure` if keychain operations fail.
    public func retrieveOathCredential(credentialId: String) async throws -> OathCredential? {
        logger?.d("Retrieving OATH credential with ID: \(credentialId)")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OathCredential?, Error>) in
            keychainQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Storage instance deallocated"))
                        return
                    }

                    // Retrieve credential metadata
                    guard let credentialData = try self.loadKeychainItem(
                        service: self.keychainService,
                        account: credentialId
                    ) else {
                        self.logger?.d("OATH credential with ID \(credentialId) not found")
                        continuation.resume(returning: nil)
                        return
                    }

                    // Retrieve secret
                    guard let secretData = try self.loadKeychainItem(
                        service: self.keychainSecretService,
                        account: credentialId
                    ) else {
                        self.logger?.e("Secret not found for credential ID \(credentialId)", error: nil)
                        throw OathStorageError.storageCorrupted("Secret missing for credential")
                    }

                    // Decode credential metadata
                    let credentialWithoutSecret = try JSONDecoder().decode(OathCredential.self, from: credentialData)

                    // Reconstruct credential with secret
                    let secret = String(data: secretData, encoding: .utf8) ?? ""
                    let credential = OathCredential.withSecret(credentialWithoutSecret, secretKey: secret)

                    self.logger?.d("Successfully retrieved OATH credential with ID: \(credentialId)")
                    continuation.resume(returning: credential)
                } catch {
                    self?.logger?.e("Failed to retrieve OATH credential with ID \(credentialId): \(error)", error: error)
                    if let storageError = error as? OathStorageError {
                        continuation.resume(throwing: storageError)
                    } else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Failed to retrieve credential", error))
                    }
                }
            }
        }
    }

    /// Get all OATH credentials from the keychain.
    /// - Returns: Array of all stored credentials.
    /// - Throws: `OathStorageError.storageFailure` if keychain operations fail.
    public func getAllOathCredentials() async throws -> [OathCredential] {
        logger?.d("Retrieving all OATH credentials")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OathCredential], Error>) in
            keychainQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Storage instance deallocated"))
                        return
                    }

                    let allItems = try self.loadAllKeychainItems(service: self.keychainService)
                    var credentials: [OathCredential] = []

                    for (account, data) in allItems {
                        do {
                            // Decode credential metadata
                            let credentialWithoutSecret = try JSONDecoder().decode(OathCredential.self, from: data)

                            // Retrieve secret
                            if let secretData = try self.loadKeychainItem(
                                service: self.keychainSecretService,
                                account: account
                            ) {
                                let secret = String(data: secretData, encoding: .utf8) ?? ""
                                let credential = OathCredential.withSecret(credentialWithoutSecret, secretKey: secret)
                                credentials.append(credential)
                            } else {
                                self.logger?.w("Secret not found for credential \(account), skipping", error: nil)
                            }
                        } catch {
                            self.logger?.w("Failed to decode credential \(account), skipping: \(error)", error: error)
                        }
                    }

                    self.logger?.d("Successfully retrieved \(credentials.count) OATH credentials")
                    continuation.resume(returning: credentials)
                } catch {
                    self?.logger?.e("Failed to retrieve all OATH credentials: \(error)", error: error)
                    if let storageError = error as? OathStorageError {
                        continuation.resume(throwing: storageError)
                    } else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Failed to retrieve credentials", error))
                    }
                }
            }
        }
    }

    /// Remove an OATH credential from the keychain.
    /// - Parameter credentialId: The ID of the credential to remove.
    /// - Returns: true if removed, false if not found.
    /// - Throws: `OathStorageError.storageFailure` if keychain operations fail.
    public func removeOathCredential(credentialId: String) async throws -> Bool {
        logger?.d("Removing OATH credential with ID: \(credentialId)")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            keychainQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Storage instance deallocated"))
                        return
                    }

                    // Remove credential metadata
                    let credentialRemoved = try self.deleteKeychainItem(
                        service: self.keychainService,
                        account: credentialId
                    )

                    // Remove secret (ignore result as credential might exist without secret in error scenarios)
                    _ = try? self.deleteKeychainItem(
                        service: self.keychainSecretService,
                        account: credentialId
                    )

                    if credentialRemoved {
                        self.logger?.d("Successfully removed OATH credential with ID: \(credentialId)")
                    } else {
                        self.logger?.d("OATH credential with ID \(credentialId) not found for removal")
                    }

                    continuation.resume(returning: credentialRemoved)
                } catch {
                    self?.logger?.e("Failed to remove OATH credential with ID \(credentialId): \(error)", error: error)
                    if let storageError = error as? OathStorageError {
                        continuation.resume(throwing: storageError)
                    } else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Failed to remove credential", error))
                    }
                }
            }
        }
    }

    /// Clear all OATH credentials from the keychain.
    /// - Throws: `OathStorageError.storageFailure` if keychain operations fail.
    public func clearOathCredentials() async throws {
        logger?.d("Clearing all OATH credentials")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            keychainQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Storage instance deallocated"))
                        return
                    }

                    // Clear all credential metadata
                    try self.deleteAllKeychainItems(service: self.keychainService)

                    // Clear all secrets
                    try self.deleteAllKeychainItems(service: self.keychainSecretService)

                    self.logger?.d("Successfully cleared all OATH credentials")
                    continuation.resume()
                } catch {
                    self?.logger?.e("Failed to clear all OATH credentials: \(error)", error: error)
                    if let storageError = error as? OathStorageError {
                        continuation.resume(throwing: storageError)
                    } else {
                        continuation.resume(throwing: OathStorageError.storageFailure("Failed to clear credentials", error))
                    }
                }
            }
        }
    }

    
    // MARK: - Private Keychain Operations

    /// Store data in the keychain with the given service and account.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    ///   - data: The data to store.
    /// - Throws: `OathStorageError` if keychain operations fail.
    private func storeKeychainItem(service: String, account: String, data: Data) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Apply security options
        let securityAttributes = securityOptions.keychainAttributes()
        query.merge(securityAttributes) { (_, new) in new }

        // First try to update existing item
        var updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = securityOptions.accessGroup {
            updateQuery[kSecAttrAccessGroup as String] = accessGroup
        }

        var updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // Apply security options to update attributes
        let securityAttributesForUpdate = securityOptions.keychainAttributes()
        updateAttributes.merge(securityAttributesForUpdate) { (_, new) in new }

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return // Successfully updated existing item
        }

        if updateStatus != errSecItemNotFound {
            throw mapKeychainError(updateStatus, operation: "update keychain item")
        }

        // Item doesn't exist, create new item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw mapKeychainError(addStatus, operation: "add keychain item")
        }
    }

    /// Load data from the keychain with the given service and account.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    /// - Returns: The stored data, or nil if not found.
    /// - Throws: `OathStorageError` if keychain operations fail.
    private func loadKeychainItem(service: String, account: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = securityOptions.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "load keychain item")
        }

        return result as? Data
    }

    /// Load all items from the keychain for a given service.
    /// - Parameter service: The keychain service identifier.
    /// - Returns: Dictionary mapping account names to data.
    /// - Throws: `OathStorageError` if keychain operations fail.
    private func loadAllKeychainItems(service: String) throws -> [String: Data] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = securityOptions.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return [:] // No items found
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "load all keychain items")
        }

        guard let items = result as? [[String: Any]] else {
            return [:]
        }

        var resultDict: [String: Data] = [:]
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               let data = item[kSecValueData as String] as? Data {
                resultDict[account] = data
            }
        }

        return resultDict
    }

    /// Delete a keychain item with the given service and account.
    /// - Parameters:
    ///   - service: The keychain service identifier.
    ///   - account: The keychain account (key).
    /// - Returns: true if item was deleted, false if not found.
    /// - Throws: `OathStorageError` if keychain operations fail.
    private func deleteKeychainItem(service: String, account: String) throws -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = securityOptions.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            return false
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "delete keychain item")
        }

        return true
    }

    /// Delete all keychain items for a given service.
    /// - Parameter service: The keychain service identifier.
    /// - Throws: `OathStorageError` if keychain operations fail.
    private func deleteAllKeychainItems(service: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = securityOptions.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        // It's okay if no items were found
        if status == errSecItemNotFound {
            return
        }

        guard status == errSecSuccess else {
            throw mapKeychainError(status, operation: "delete all keychain items")
        }
    }

    /// Maps keychain error codes to OathStorageError using enhanced error handler.
    /// - Parameters:
    ///   - status: The keychain operation status code.
    ///   - operation: Description of the operation that failed.
    ///   - account: Optional account identifier for context.
    /// - Returns: Appropriate OathStorageError.
    private func mapKeychainError(_ status: OSStatus, operation: String, account: String? = nil) -> OathStorageError {
        return OathKeychainErrorHandler.mapKeychainError(
            status,
            operation: operation,
            account: account,
            logger: logger
        )
    }
}
