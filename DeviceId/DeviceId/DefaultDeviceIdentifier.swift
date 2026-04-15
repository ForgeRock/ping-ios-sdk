//
//  DefaultDeviceIdentifier.swift
//  DeviceId
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CryptoKit
import PingLogger
import PingStorage

/// Default implementation that generates and persists a device identifier.
/// Implements `DeviceIdentifier` protocol to provide a unique identifier for the device.
/// Example usage:
/// ```swift
/// let deviceId = DefaultDeviceIdentifier()
/// let identifier = try await deviceId.id
///
/// // In case of migration from the FR SDK when using a custom Keychain Access Group use the following
///
///
/// func setupDeviceIdentifierWithMigration() async throws -> String {
///     // If your legacy FRAuth SDK used a custom keychain access group,
///     // specify it here to enable migration
///     let configuration = DeviceIdentifierConfiguration(
///         keySize: DeviceIdentifierConfiguration.default.keySize,
///         keychainAccount: DeviceIdentifierConfiguration.default.keychainAccount,
///         useEncryption: DeviceIdentifierConfiguration.default.useEncryption,
///         legacyKeychainAccessGroup: "com.test" // Set Legacy Keychain Access Group
///     )
///
///     // Initialize with configuration
///    let deviceIdentifier = try DefaultDeviceIdentifier(
///         configuration: configuration,
///         logger: LogManager.standard  // Optional: for debugging migration
///     )
///
///     // First access will trigger migration if legacy identifier exists
///     let deviceId = try await deviceIdentifier.id
///     print("Device ID: \(deviceId)")
///
///     return deviceId
/// }
/// ```
public actor DefaultDeviceIdentifier: DeviceIdentifier, Sendable {
    /// Configuration for the device identifier
    private let configuration: DeviceIdentifierConfiguration
    /// Keychain storage service for persisting the device identifier.
    internal let keychainService: any Storage<DeviceIdentifierImpl>
    /// Optional logger for logging events.
    private let logger: Logger?
    /// In-memory cache for the computed identifier.
    private var cachedId: String?
    /// A task handle for an in-progress generation to prevent race conditions.
    private var generationTask: Task<String, Error>?
    
    /// The unique identifier for the device.
    /// This identifier is either retrieved from the keychain or generated if it does not exist.
    public var id: String {
        get async throws {
            // Fast-path: in-memory cache
            if let id = cachedId {
                logger?.i("Returning cached device identifier")
                return id
            }
            // If a generation task is already running, await its result.
            if let existingTask = generationTask {
                return try await existingTask.value
            }
            
            // No cached ID and no task running, so start a new one.
            let idTask = Task {
                // Ensure the task handle is cleared when this scope exits.
                defer { generationTask = nil }
                return try await getOrCreateIdentifier()
            }
            
            // Store the handle to the new task so other callers can await it.
            self.generationTask = idTask
            
            // Wait for the result and return it.
            return try await idTask.value
        }
    }
    
    /// Initializes a new instance of `DefaultDeviceIdentifier` with custom configuration.
    /// - Parameters:
    ///   - configuration: Configuration for device identifier behavior
    ///   - logger: An optional logger to log events. Defaults to `nil`.
    public init(configuration: DeviceIdentifierConfiguration = .default, logger: Logger? = nil) throws {
        self.configuration = configuration
        self.logger = logger
        
        // Create keychain service based on configuration
        let encryptor: any Encryptor
        if configuration.useEncryption {
            guard let secured = SecuredKeyEncryptor() else {
                // Throw a specific error
                throw DeviceIdentifierError.encryptionInitializationFailed
            }
            encryptor = secured
        } else {
            encryptor = NoEncryptor()
        }
        
        self.keychainService = KeychainStorage<DeviceIdentifierImpl>(
            account: configuration.keychainAccount,
            encryptor: encryptor
        )
    }
    
    /// Initializes with custom storage (for testing or advanced use cases)
    /// - Parameters:
    ///  - configuration: Configuration for device identifier behavior
    ///  - storage: Custom storage implementation
    ///  - logger: Optional logger
    /// - Note: When using custom storage, configuration settings for keychain are ignored
    public init(configuration: DeviceIdentifierConfiguration = .default, storage: any Storage<DeviceIdentifierImpl>, logger: Logger? = nil) {
        self.configuration = configuration
        self.keychainService = storage
        self.logger = logger
    }
    
    /// Clears the cached identifier.
    public func clearCache() {
        cachedId = nil
    }
    
    /// Asynchronously regenerates the device identifier by deleting the existing keychain item.
    /// This method cancels any ongoing generation task and clears the cache.
    /// Also clears any legacy identifier storage to ensure a completely new identifier is generated.
    /// - Throws: `DeviceIdentifierError` if keychain operations fail.
    /// - Returns: The new unique identifier for the device.
    public func regenerateIdentifier() async throws -> String {
        logger?.i("Regenerating device identifier")
        // Cancel any ongoing generation task, as it's now stale.
        generationTask?.cancel()
        generationTask = nil
        
        clearCache()
        
        // Delete from new storage
        try await keychainService.delete()
        
        // Delete from legacy storage using direct keychain calls
        await deleteLegacyIdentifiers()
        
        return try await self.id
    }
    
    /// Deletes legacy identifiers from keychain
    private func deleteLegacyIdentifiers() async {
        // Delete legacy identifier
        let identifierQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier
        ]
        
        let identifierStatus = SecItemDelete(identifierQuery as CFDictionary)
        if identifierStatus == errSecSuccess {
            logger?.i("Deleted legacy identifier")
        } else if identifierStatus != errSecItemNotFound {
            logger?.w("Failed to delete legacy identifier. Status: \(identifierStatus)", error: nil)
        }
        
        // Delete legacy public key data
        let publicKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData
        ]
        
        let publicKeyStatus = SecItemDelete(publicKeyQuery as CFDictionary)
        if publicKeyStatus == errSecSuccess {
            logger?.i("Deleted legacy public key data")
        } else if publicKeyStatus != errSecItemNotFound {
            logger?.w("Failed to delete legacy public key data. Status: \(publicKeyStatus)", error: nil)
        }
        
        // Delete legacy private key data (if it exists)
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.privateKeyData
        ]
        
        let privateKeyStatus = SecItemDelete(privateKeyQuery as CFDictionary)
        if privateKeyStatus == errSecSuccess {
            logger?.i("Deleted legacy private key data")
        } else if privateKeyStatus != errSecItemNotFound {
            logger?.w("Failed to delete legacy private key data. Status: \(privateKeyStatus)", error: nil)
        }
    }
    
    /// Performs the logic of getting an ID from keychain or generating a new one.
    /// This function should only be called from within a single Task to prevent races.
    /// - Throws: `DeviceIdentifierError` if key generation or keychain operations fail.
    /// - Returns: The unique identifier for the device.
    private func getOrCreateIdentifier() async throws -> String {
        // 1. Try the keychain first
        if let stored = try await keychainService.get() {
            let id = try await stored.id
            logger?.i("Retrieved device identifier from keychain")
            cachedId = id // Cache the result
            return id
        }
        
        // 2. Check for legacy device identifier before generating new one
        logger?.i("Checking for legacy device identifier")
        do {
            if let legacyId = try await migrateLegacyIdentifier() {
                logger?.i("Successfully migrated legacy device identifier")
                cachedId = legacyId
                return legacyId
            }
            // No legacy identifier found, continue to generation
            logger?.d("No legacy identifier found, will generate new one")
        } catch {
            // Migration found a legacy ID but failed to store it in new format
            // Log the error and continue with generating a new identifier
            logger?.e("Failed to migrate legacy device identifier, will generate new one instead", error: error)
            // Fall through to generation step below
        }
        
        // 3. Keychain is empty and no legacy identifier, so generate a new key pair
        logger?.i("Generating new device identifier key pair")
        let keyPair = try await generateKeyPair()
        
        // 4. Persist and cache the new identifier
        let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: keyPair)
        try await keychainService.save(item: impl)
        let identifier = try await impl.id
        cachedId = identifier // Cache the result
        return identifier
    }
    
    /// Attempts to migrate a legacy device identifier from FRAuth SDK format
    /// - Returns: The legacy identifier if found and successfully migrated, otherwise nil
    private func migrateLegacyIdentifier() async throws -> String? {
        let legacyIdentifier = LegacyDeviceIdentifier(
            accessGroup: configuration.legacyKeychainAccessGroup,
            logger: logger
        )
        
        // First try direct retrieval of the identifier string
        if let legacyId = try await legacyIdentifier.getLegacyIdentifier() {
            logger?.i("Found legacy identifier string via direct keychain query")
            // Store in new format with empty key pair (identifier only)
            try await storeLegacyIdentifierInNewFormat(legacyId, keyPair: nil)
            return legacyId
        }
        
        // If direct retrieval failed, try migrating the full key pair from system keychain
        if let migration = try await legacyIdentifier.migrateLegacyKeyPair() {
            logger?.i("Successfully migrated legacy key pair from system keychain")
            // Store both the identifier and the actual key pair data
            try await storeLegacyIdentifierInNewFormat(migration.identifier, keyPair: migration.keyPair)
            return migration.identifier
        }
        
        logger?.d("No legacy identifier found to migrate")
        return nil
    }
    
    /// Stores the legacy identifier in the new DeviceIdentifierImpl format
    /// - Parameters:
    ///   - legacyId: The legacy identifier to store
    ///   - keyPair: Optional key pair data (if available from system keychain migration)
    private func storeLegacyIdentifierInNewFormat(_ legacyId: String, keyPair: DeviceIdentifierKeyPair?) async throws {
        logger?.i("Storing migrated legacy identifier in new format")
        
        let finalKeyPair: DeviceIdentifierKeyPair
        if let keyPair = keyPair {
            // We have the actual key pair from legacy system keychain
            logger?.i("Storing with migrated key pair (public: \(keyPair.publicKey.count) bytes, private: \(keyPair.privateKey?.count ?? 0) bytes)")
            finalKeyPair = keyPair
        } else {
            // We only have the identifier string, use empty key data
            logger?.i("Storing identifier only (no key pair available)")
            finalKeyPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
        }
        
        let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: finalKeyPair, legacyIdentifier: legacyId)
        try await keychainService.save(item: impl)
    }
    
    /// Asynchronously generates a key pair on a background task.
    /// - Throws: `DeviceIdentifierError` if key generation fails.
    /// - Returns: A `DeviceIdentifierKeyPair` containing the private and public keys.
    private func generateKeyPair() async throws -> DeviceIdentifierKeyPair {
        try await Task.detached(priority: .userInitiated) { [configuration] in
            try DefaultDeviceIdentifier.generateKeyPairSync(keySize: configuration.keySize)
        }.value
    }
    
    /// Synchronous key-pair generation logic.
    /// - Throws: `DeviceIdentifierError` if key generation fails.
    /// - Returns: A `DeviceIdentifierKeyPair` containing the private and public keys.
    private static func generateKeyPairSync(keySize: Int) throws -> DeviceIdentifierKeyPair {
        let (privData, pubData) = try generateRSAKeyPairData(
            keySize: keySize
        )
        return DeviceIdentifierKeyPair(privateKey: privData, publicKey: pubData)
    }
    
    /// Generates an RSA key pair and returns the private and public key data.
    /// - Parameters:
    ///  - keySize: The size of the RSA key in bits.
    /// - Throws: `DeviceIdentifierError` if key generation or export fails.
    /// - Returns: A tuple containing the private key data and public key data.
    private static func generateRSAKeyPairData(keySize: Int) throws -> (Data, Data) {
        // Ephemeral RSA key generation for performance
        let attributes: CFDictionary = [
            kSecAttrKeyType as CFString: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as CFString: keySize
        ] as CFDictionary
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
            let err = error?.takeRetainedValue() as Error?
            ?? NSError(domain: NSOSStatusErrorDomain,
                       code: Int(errSecInternalError),
                       userInfo: [NSLocalizedDescriptionKey: "Unknown key generation error"])
            throw DeviceIdentifierError.keyGenerationFailed(err)
        }
        // Helper to export raw key data
        func exportKey(_ key: SecKey) throws -> Data {
            var exportError: Unmanaged<CFError>?
            guard let dataRef = SecKeyCopyExternalRepresentation(key, &exportError) else {
                let err = exportError?.takeRetainedValue() as Error?
                ?? NSError(domain: NSOSStatusErrorDomain,
                           code: Int(errSecInternalError),
                           userInfo: [NSLocalizedDescriptionKey: "Unable to export key"])
                throw DeviceIdentifierError.externalRepresentationFailed(err)
            }
            return dataRef as Data
        }
        let privateKeyData = try exportKey(privateKey)
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw DeviceIdentifierError.publicKeyExtractionFailed
        }
        let publicKeyData = try exportKey(publicKey)
        return (privateKeyData, publicKeyData)
    }
}
