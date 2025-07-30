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
    /// The private key data.
    let privateKey: Data
    /// The public key data.
    let publicKey: Data
}

/// Default implementation that generates and persists a device identifier.
public actor DefaultDeviceIdentifier: DeviceIdentifier {
    /// Keychain storage service for persisting the device identifier.
    private let keychainService: any Storage<DeviceIdentifierImpl>
    /// Optional logger for logging events.
    private let logger: Logger?
    /// In-memory cache for the computed identifier.
    private var cachedId: String?
    
    /// The unique identifier for the device.
    /// This identifier is either retrieved from the keychain or generated if it does not exist.
    public var id: String {
        get async throws {
            if let inMemory = cachedId {
                logger?.i("Returning cached device identifier")
                return inMemory
            }
            if let stored = try await keychainService.get() {
                logger?.i("Retrieved device identifier from keychain")
                return stored.id
            }
            // Generate and save new identifier
            do {
                let keyPair = try await generateKeyPair()
                let identifier = hashSHA256AndTransformToHex(keyPair.publicKey)
                let impl = DeviceIdentifierImpl(deviceIdentifierKeyPair: keyPair)
                try await keychainService.save(item: impl)
                return identifier
            } catch {
                logger?.e("Key pair generation failed", error: error)
                logger?.i("Falling back to UUID-based identifier")
                let uuidData = Data(UUID().uuidString.utf8)
                let identifier = hashSHA256AndTransformToHex(uuidData)
                let fallbackPair = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
                let fallback = DeviceIdentifierImpl(deviceIdentifierKeyPair: fallbackPair)
                try await keychainService.save(item: fallback)
                return identifier
            }
        }
    }
    
    /// Initializes a new instance of `DefaultDeviceIdentifier`.
    /// - Parameter logger: An optional logger to log events. Defaults to `nil`.
    public init(logger: Logger? = nil) {
        self.logger = logger
        self.keychainService = KeychainStorage<DeviceIdentifierImpl>(
            account: Constants.deviceIdentifierKey,
            encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
        )
    }
        
    /// Asynchronously generates a key pair on a background task.
    /// - Throws: `DeviceIdentifierError` if key generation fails.
    /// - Returns: A `DeviceIdentifierKeyPair` containing the private and public keys.
    private func generateKeyPair() async throws -> DeviceIdentifierKeyPair {
        try await Task.detached(priority: .userInitiated) {
            try DefaultDeviceIdentifier.generateKeyPairSync()
        }.value
    }
    
    /// Synchronous key-pair generation logic.
    /// - Throws: `DeviceIdentifierError` if key generation fails.
    /// - Returns: A `DeviceIdentifierKeyPair` containing the private and public keys.
    private static func generateKeyPairSync() throws -> DeviceIdentifierKeyPair {
        let (privData, pubData) = try self.generateRSAKeyPairData(
            keySize: Constants.keySize,
            publicTag: Constants.publicKeyTag.data(using: .utf8) ?? Data(),
            privateTag: Constants.privateKeyTag.data(using: .utf8) ?? Data()
        )
        return DeviceIdentifierKeyPair(privateKey: privData, publicKey: pubData)
    }
    
    /// Generates an RSA key pair and returns the private and public key data.
    /// - Parameters:
    ///  - keySize: The size of the RSA key in bits.
    ///  - publicTag: The tag for the public key.
    ///  - privateTag: The tag for the private key.
    ///  - Throws: `DeviceIdentifierError` if key generation or export fails.
    ///  - Returns: A tuple containing the private key data and public key data.
    private static func generateRSAKeyPairData(
        keySize: Int,
        publicTag: Data,
        privateTag: Data
    ) throws -> (Data, Data) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: keySize,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: privateTag
            ],
            kSecPublicKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: publicTag
            ]
        ]
        var cfError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &cfError) else {
            let err = cfError?.takeRetainedValue() as Error?
            ?? NSError(domain: NSOSStatusErrorDomain,
                       code: Int(errSecInternalError),
                       userInfo: [NSLocalizedDescriptionKey: "Unknown key generation error"])
            throw DeviceIdentifierError.keyGenerationFailed(err)
        }
        // Export private key
        var cfErrorPriv: Unmanaged<CFError>?
        guard let privDataRef = SecKeyCopyExternalRepresentation(privateKey, &cfErrorPriv) else {
            let err = cfErrorPriv?.takeRetainedValue() as Error?
            ?? NSError(domain: NSOSStatusErrorDomain,
                       code: Int(errSecInternalError),
                       userInfo: [NSLocalizedDescriptionKey: "Unable to export private key"])
            throw DeviceIdentifierError.externalRepresentationFailed(err)
        }
        let privateKeyData = privDataRef as Data
        
        // Extract and export public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw DeviceIdentifierError.publicKeyExtractionFailed
        }
        var cfErrorPub: Unmanaged<CFError>?
        guard let pubDataRef = SecKeyCopyExternalRepresentation(publicKey, &cfErrorPub) else {
            let err = cfErrorPub?.takeRetainedValue() as Error?
            ?? NSError(domain: NSOSStatusErrorDomain,
                       code: Int(errSecInternalError),
                       userInfo: [NSLocalizedDescriptionKey: "Unable to export public key"])
            throw DeviceIdentifierError.externalRepresentationFailed(err)
        }
        let publicKeyData = pubDataRef as Data
        return (privateKeyData, publicKeyData)
    }
}

/// Concrete identifier storing only key pair; `id` is computed.
public final class DeviceIdentifierImpl: DeviceIdentifier, Codable {
    /// The key pair used for device identification, containing both private and public keys.
    let deviceIdentifierKeyPair: DeviceIdentifierKeyPair
    /// The unique identifier for the device, computed as a SHA-256 hash of the public key.
    public var id: String { hashSHA256AndTransformToHex(deviceIdentifierKeyPair.publicKey) }
    /// Initializes a new instance of `DeviceIdentifierImpl`.
    init(deviceIdentifierKeyPair: DeviceIdentifierKeyPair) {
        self.deviceIdentifierKeyPair = deviceIdentifierKeyPair
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
    static let publicKeyTag = "com.pingidentity.deviceIdentifier.public-key"
    static let privateKeyTag = "com.pingidentity.deviceIdentifier.private-key"
    static let keySize = 2048
}

public enum DeviceIdentifierError: Error {
    case keyGenerationFailed(Error)
    case publicKeyExtractionFailed
    case externalRepresentationFailed(Error)
}
