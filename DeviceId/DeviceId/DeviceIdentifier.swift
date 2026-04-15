//
//  DeviceIdentifier.swift
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
    /// Optional keychain access group used by the legacy SDK for migration purposes.
    /// If your app used a custom keychain access group with the legacy FRAuth SDK,
    /// specify it here to enable migration of the legacy device identifier.
    public let legacyKeychainAccessGroup: String?
    
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
    
    public init(keySize: Int, keychainAccount: String, useEncryption: Bool = true, legacyKeychainAccessGroup: String? = nil) {
        self.keySize = keySize
        self.keychainAccount = keychainAccount
        self.useEncryption = useEncryption
        self.legacyKeychainAccessGroup = legacyKeychainAccessGroup
    }
}

/// Concrete identifier storing only key pair; `id` is computed.
public final class DeviceIdentifierImpl: DeviceIdentifier, Codable, Sendable {
    /// The key pair used for device identification, containing both private and public keys.
    let deviceIdentifierKeyPair: DeviceIdentifierKeyPair
    /// An optional legacy identifier, used for migration from older versions.
    let legacyIdentifier: String?
    
    /// The unique identifier for the device, computed as a SHA-256 hash of the public key.
    public var id: String {
        get async throws {
            // If this is a migrated legacy identifier, return it directly
            if let legacy = legacyIdentifier {
                return legacy
            }
            // Hashing is synchronous, so this never actually suspends or throws,
            // but it satisfies the protocol requirement exactly.
            return hashSHA256AndTransformToHex(deviceIdentifierKeyPair.publicKey)
        }
    }
    
    /// Initializes a new instance of `DeviceIdentifierImpl`.
    /// - Parameters:
    ///   - deviceIdentifierKeyPair: The key pair for the device identifier.
    ///   - legacyIdentifier: An optional legacy identifier for migration purposes. Defaults to `nil`.
    public init(deviceIdentifierKeyPair: DeviceIdentifierKeyPair, legacyIdentifier: String? = nil) {
        self.deviceIdentifierKeyPair = deviceIdentifierKeyPair
        self.legacyIdentifier = legacyIdentifier
    }
}

extension Data {
    /// Converts the `Data` instance to a hexadecimal string representation.
    nonisolated func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum Constants {
    static let deviceIdentifierKey = "com.pingidentity.deviceIdentifier"
    static let keySize = 2048
    static let deviceIdentifierKeySecure = "com.pingidentity.deviceIdentifier.secure"
    static let keySizeSecure = 4096
    static let uuidFallbackKey = "com.pingidentity.deviceIdentifier.uuidFallback"
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
public enum DeviceIdentifierError: Error, LocalizedError, Sendable {
    case encryptionInitializationFailed
    case keyGenerationFailed(Error)
    case publicKeyExtractionFailed
    case externalRepresentationFailed(Error)
    case keychainItemNotFound
    case keychainUnexpectedData
    case keychainUnexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encryptionInitializationFailed:
            return "Encryption initialization failed."
        case .keyGenerationFailed(let error):
            return "Key generation failed: \(error.localizedDescription)"
        case .publicKeyExtractionFailed:
            return "Failed to extract the public key."
        case .externalRepresentationFailed(let error):
            return "Failed to export key to external representation: \(error.localizedDescription)"
        case .keychainItemNotFound:
            return "Keychain item not found."
        case .keychainUnexpectedData:
            return "Unexpected data format in keychain."
        case .keychainUnexpectedStatus(let status):
            return "Unexpected keychain status code: \(status)."
        }
    }
}
