//
//  MockOathStorage.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOath

/// In-memory mock implementation of `OathStorage` for use in unit tests.
actor MockOathStorage: OathStorage {

    private var credentials: [String: OathCredential] = [:]

    // MARK: - Test Helpers

    /// Returns all credentials currently stored (for assertions).
    func getAllCredentials() -> [OathCredential] {
        Array(credentials.values)
    }

    /// Pre-populates the storage with a credential (for duplicate-detection tests).
    func seedCredential(_ credential: OathCredential) {
        credentials[credential.id] = credential
    }

    // MARK: - OathStorage

    func storeOathCredential(_ credential: OathCredential) async throws {
        credentials[credential.id] = credential
    }

    func retrieveOathCredential(credentialId: String) async throws -> OathCredential? {
        credentials[credentialId]
    }

    func getAllOathCredentials() async throws -> [OathCredential] {
        Array(credentials.values)
    }

    func removeOathCredential(credentialId: String) async throws -> Bool {
        let existed = credentials[credentialId] != nil
        credentials.removeValue(forKey: credentialId)
        return existed
    }

    func getCredentialByIssuerAndAccount(issuer: String, accountName: String) async throws -> OathCredential? {
        credentials.values.first { $0.issuer == issuer && $0.accountName == accountName }
    }

    func clearOathCredentials() async throws {
        credentials.removeAll()
    }
}
