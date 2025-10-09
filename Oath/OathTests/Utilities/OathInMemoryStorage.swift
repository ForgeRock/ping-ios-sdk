//
//  OathInMemoryStorage.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
@testable import PingOath

/// In-memory storage implementation for OATH credentials, designed for unit testing.
/// This implementation stores credentials in memory and provides the same interface
/// as the keychain storage but without external dependencies.
actor OathInMemoryStorage: OathStorage {

    // MARK: - Properties

    private var credentials: [String: OathCredential] = [:]

    // MARK: - OathStorage Implementation

    func storeOathCredential(_ credential: OathCredential) async throws {
        credentials[credential.id] = credential
    }

    func retrieveOathCredential(credentialId: String) async throws -> OathCredential? {
        return credentials[credentialId]
    }

    func getAllOathCredentials() async throws -> [OathCredential] {
        return Array(credentials.values)
    }

    func removeOathCredential(credentialId: String) async throws -> Bool {
        let existed = credentials[credentialId] != nil
        credentials.removeValue(forKey: credentialId)
        return existed
    }

    func clearOathCredentials() async throws {
        credentials.removeAll()
    }

    // MARK: - Test Utilities

    /// Get the count of stored credentials (for testing).
    var credentialCount: Int {
        return credentials.count
    }

    /// Check if a credential exists (for testing).
    func hasCredential(id: String) -> Bool {
        return credentials[id] != nil
    }
}