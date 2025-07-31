//
//  DeviceIdentifier.swift
//  DeviceId
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CryptoKit
import PingLogger
import PingStorage

/// A protocol that defines a unique identifier for a device.
public protocol DeviceIdentifier: Sendable {
    /// Returns a unique identifier for the device.
    var id: String { get async throws }
}

/// An extension of `DeviceIdentifier` that provides a method to hash data using SHA256 and transform it to a hexadecimal string.
extension DeviceIdentifier {
    /// Hashes the given data using SHA256 and transforms it into a hexadecimal string.
    /// - Parameter data: The data to be hashed.
    /// - Returns: A hexadecimal string representation of the SHA256 hash of the data.
    func hashSHA256AndTransformToHex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).toHexString()
    }
}

/// A struct that represents a key pair for device identification, containing both private and public keys.
public struct DeviceIdentifierKeyPair: Codable, Sendable {
    /// The private key data. Optional, but keeping reference for future use. This will be persisted securely as it might be used for signing or encryption in the future.
    let privateKey: Data?
    /// The public key data.
    let publicKey: Data
}

/// Configuration for device identifier, including key size and keychain account.
/// This configuration is used to initialize the device identifier and can be customized if needed.
public struct DeviceIdentifierConfiguration : Sendable {
    /// RSA key size in bits
    public let keySize: Int
    /// Keychain account identifier
    public let keychainAccount: String
    /// Whether to use encryption for keychain storage
    public let useEncryption: Bool
    
    /// Default configuration
    public static let `default` = DeviceIdentifierConfiguration(
        keySize: Constants.keySize,
        keychainAccount: Constants.deviceIdentifierKey,
        useEncryption: true
    )
    
    /// High security configuration with larger key size
    public static let highSecurity = DeviceIdentifierConfiguration(
        keySize: Constants.keySizeSecure,     // 4096
        keychainAccount: Constants.deviceIdentifierKeySecure,
        useEncryption: true
    )
    
    public init(keySize: Int, keychainAccount: String, useEncryption: Bool = true) {
        self.keySize = keySize
        self.keychainAccount = keychainAccount
        self.useEncryption = useEncryption
    }
}

/// Concrete identifier storing only key pair; `id` is computed.
public final class DeviceIdentifierImpl: DeviceIdentifier, Codable, Sendable {
    /// The key pair used for device identification, containing both private and public keys.
    let deviceIdentifierKeyPair: DeviceIdentifierKeyPair
    /// The unique identifier for the device, computed as a SHA-256 hash of the public key.
    public var id: String {
        get async throws {
            // Hashing is synchronous, so this never actually suspends or throws,
            // but it satisfies the protocol requirement exactly.
            hashSHA256AndTransformToHex(deviceIdentifierKeyPair.publicKey)
        }
    }
    /// Initializes a new instance of `DeviceIdentifierImpl`.
    public init(deviceIdentifierKeyPair: DeviceIdentifierKeyPair) {
        self.deviceIdentifierKeyPair = deviceIdentifierKeyPair
    }
}

/// Default implementation that generates and persists a device identifier.
/// Implements `DeviceIdentifier` protocol to provide a unique identifier for the device.
/// Example usage:
/// ```swift
/// let deviceId = DefaultDeviceIdentifier()
/// let identifier = try await deviceId.id
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
    /// - Throws: `DeviceIdentifierError` if keychain operations fail.
    /// - Returns: The new unique identifier for the device.
    public func regenerateIdentifier() async throws -> String {
        logger?.i("Regenerating device identifier")
        // Cancel any ongoing generation task, as it's now stale.
        generationTask?.cancel()
        generationTask = nil
        
        clearCache()
        try await keychainService.delete()
        return try await self.id
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
        
        // 2. Keychain is empty, so generate a new key pair
        let keyPair: DeviceIdentifierKeyPair
        do {
            logger?.i("Generating new device identifier key pair")
            keyPair = try await generateKeyPair()
        } catch {
            logger?.e("Key pair generation failed", error: error)
            logger?.i("Falling back to UUID-based identifier")
            let uuid = UUID()
            let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Data($0) }
            keyPair = DeviceIdentifierKeyPair(privateKey: nil, publicKey: uuidBytes)
        }
        
        // 3. Persist and cache the new identifier
        let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: keyPair)
        try await keychainService.save(item: impl)
        let identifier = try await impl.id
        cachedId = identifier // Cache the result
        return identifier
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

extension Data {
    /// Converts the `Data` instance to a hexadecimal string representation.
    nonisolated func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private enum Constants {
    static let deviceIdentifierKey = "com.pingidentity.deviceIdentifier"
    static let keySize = 2048
    static let deviceIdentifierKeySecure = "com.pingidentity.deviceIdentifier.secure"
    static let keySizeSecure = 4096
}

/// This enum defines various errors that can occur during device identifier operations, such as key generation failures or public key extraction issues.
/// It conforms to the `Error` protocol, allowing it to be thrown and caught in error handling contexts.
/// The cases include:
/// - encryptionInitializationFailed: Indicates that the encryption initialization failed, which may prevent secure storage of keys in the keychain.
/// - keyGenerationFailed: Indicates that the key generation process failed, with an associated error.
/// - publicKeyExtractionFailed: Indicates that the public key could not be extracted from the private key.
/// - externalRepresentationFailed: Indicates that exporting the key to external representation failed, with an associated error.
/// - keychainItemNotFound: Indicates that the keychain item was not found.
/// - keychainUnexpectedData: Indicates that the data retrieved from the keychain was not as expected.
/// - keychainUnexpectedStatus: Indicates an unexpected status code from the keychain operation, with the associated `OSStatus` code.
public enum DeviceIdentifierError: Error {
    case encryptionInitializationFailed
    case keyGenerationFailed(Error)
    case publicKeyExtractionFailed
    case externalRepresentationFailed(Error)
    case keychainItemNotFound
    case keychainUnexpectedData
    case keychainUnexpectedStatus(OSStatus)
}
