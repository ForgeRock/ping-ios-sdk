//
//  OathStorage.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol for OATH-specific storage operations.
/// Extends the base storage capabilities with OATH-specific functionality.
///
/// Implementations of this protocol must be thread-safe and handle concurrent access properly.
public protocol OathStorage: Sendable {

    /// Store an OATH credential.
    /// - Parameter credential: The OATH credential to be stored.
    /// - Throws: `OathStorageError.storageFailure` if the credential cannot be stored.
    /// - Throws: `OathStorageError.duplicateCredential` if a credential with the same ID already exists.
    func storeOathCredential(_ credential: OathCredential) async throws

    /// Retrieve an OATH credential by its ID.
    /// - Parameter credentialId: The ID of the credential to retrieve.
    /// - Returns: The OATH credential, or nil if not found.
    /// - Throws: `OathStorageError.storageFailure` if the credential cannot be retrieved.
    func retrieveOathCredential(credentialId: String) async throws -> OathCredential?

    /// Get all OATH credentials.
    /// - Returns: A list of all OATH credentials.
    /// - Throws: `OathStorageError.storageFailure` if the credentials cannot be retrieved.
    func getAllOathCredentials() async throws -> [OathCredential]

    /// Remove an OATH credential by its ID.
    /// - Parameter credentialId: The ID of the credential to remove.
    /// - Returns: true if the credential was successfully removed, false if it didn't exist.
    /// - Throws: `OathStorageError.storageFailure` if the credential cannot be removed.
    func removeOathCredential(credentialId: String) async throws -> Bool

    /// Clear all OATH credentials from the storage.
    /// - Throws: `OathStorageError.storageFailure` if the credentials cannot be cleared.
    func clearOathCredentials() async throws
}
