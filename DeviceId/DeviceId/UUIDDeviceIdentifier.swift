//
//  UUIDDeviceIdentifier.swift
//  DeviceId
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingStorage

/// A fallback device identifier that uses a UUID when key pair generation fails.
/// It generates and persists a UUID, then computes the ID by hashing the UUID's bytes.
/// Example usage:
/// ```swift
/// let deviceId = UUIDDeviceIdentifier()
/// let identifier = try await deviceId.id
/// ```
public actor UUIDDeviceIdentifier: DeviceIdentifier, Sendable {
    /// Keychain storage service for persisting the UUID data.
    internal let storage: any Storage<Data>
    /// Optional logger for logging events.
    private let logger: Logger?
    /// In-memory cache for the computed identifier.
    private var cachedId: String?

    /// The unique identifier for the device, computed from a persisted UUID.
    /// This identifier is either retrieved from the keychain or generated if it does not exist.
    public var id: String {
        get async throws {
            // Fast-path: in-memory cache
            if let id = cachedId {
                logger?.i("Returning cached fallback UUID identifier")
                return id
            }
            
            // Get or create the underlying UUID data
            let uuidData = try await getOrCreateUUIDData()
            
            // Compute the final ID by hashing the data
            let identifier = hashSHA256AndTransformToHex(uuidData)
            
            // Cache and return the result
            self.cachedId = identifier
            return identifier
        }
    }

    /// Initializes a new instance of `UUIDDeviceIdentifier`.
    /// - Parameters:
    ///   - logger: An optional logger to log events. Defaults to `nil`.
    public init(logger: Logger? = nil) {
        // Initialize the keychain storage with a fallback UUID key.
        self.storage = KeychainStorage<Data>(account: Constants.uuidFallbackKey, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
        self.logger = logger
    }
    
    /// Retrieves UUID data from keychain or generates and saves a new one.
    /// - Returns: The `Data` representation of the UUID.
    /// - Throws: An error if the UUID cannot be retrieved or generated.
    private func getOrCreateUUIDData() async throws -> Data {
        // 1. Try the keychain first
        if let storedData = try await storage.get() {
            logger?.i("Retrieved fallback UUID from keychain")
            return storedData
        }
        
        // 2. Keychain is empty, so generate a new UUID
        logger?.i("Generating new fallback UUID")
        let uuid = UUID()
        let uuidData = withUnsafeBytes(of: uuid.uuid) { Data($0) }
        
        // 3. Persist the new UUID data
        try await storage.save(item: uuidData)
        
        return uuidData
    }
}
