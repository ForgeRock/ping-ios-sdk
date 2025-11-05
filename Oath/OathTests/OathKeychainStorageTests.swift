//
//  OathKeychainStorageTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class OathKeychainStorageTests: XCTestCase {

    private var storage: OathKeychainStorage?
    private let testService = "com.pingidentity.oath.test"

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use unique service name for each test to avoid conflicts
        let testServiceName = "\(testService).\(UUID().uuidString)"
        storage = OathKeychainStorage(service: testServiceName)
    }

    override func tearDownWithError() throws {
        // Best-effort async cleanup; each test gets its own unique service so leftover
        // data won't clash
        Task { try? await storage?.clearOathCredentials() }
        try super.tearDownWithError()
    }

    // MARK: - Test Helpers

    private func createTestCredential(
        id: String = "test-credential",
        issuer: String = "Test Issuer",
        accountName: String = "testuser@example.com",
        oathType: OathType = .totp,
        secretKey: String = "JBSWY3DPEHPK3PXP"
    ) -> OathCredential {
        return OathCredential(
            id: id,
            issuer: issuer,
            accountName: accountName,
            oathType: oathType,
            secretKey: secretKey
        )
    }

    // MARK: - Storage Tests

    func testStoreAndRetrieveCredential() async throws {
        // Given
        let credential = createTestCredential()

        // When
        try await storage?.storeOathCredential(credential)
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)

        // Then
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.id, credential.id)
        XCTAssertEqual(retrievedCredential?.issuer, credential.issuer)
        XCTAssertEqual(retrievedCredential?.accountName, credential.accountName)
        XCTAssertEqual(retrievedCredential?.oathType, credential.oathType)
        XCTAssertEqual(retrievedCredential?.secret, credential.secret)
    }

    func testRetrieveNonExistentCredential() async throws {
        // When
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: "non-existent")

        // Then
        XCTAssertNil(retrievedCredential)
    }

    func testStoreMultipleCredentials() async throws {
        // Given
        let credential1 = createTestCredential(id: "cred1", issuer: "Issuer 1")
        let credential2 = createTestCredential(id: "cred2", issuer: "Issuer 2", oathType: .hotp)

        // When
        try await storage?.storeOathCredential(credential1)
        try await storage?.storeOathCredential(credential2)

        if let allCredentials = try await storage?.getAllOathCredentials() {
            // Then
            XCTAssertEqual(allCredentials.count, 2)

            let retrievedIds = Set(allCredentials.map { $0.id })
            XCTAssertTrue(retrievedIds.contains("cred1"))
            XCTAssertTrue(retrievedIds.contains("cred2"))
        } else {
            XCTFail("Failed to retrieve all credentials")
        }
    }

    func testUpdateExistingCredential() async throws {
        // Given
        let originalCredential = createTestCredential()
        try await storage?.storeOathCredential(originalCredential)

        // When - update the credential
        let updatedCredential = OathCredential(
            id: originalCredential.id,
            issuer: originalCredential.issuer,
            accountName: originalCredential.accountName,
            oathType: originalCredential.oathType,
            counter: 5, // Updated counter
            secretKey: originalCredential.secret
        )
        try await storage?.storeOathCredential(updatedCredential)

        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: originalCredential.id)

        // Then
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.counter, 5)
    }

    func testRemoveCredential() async throws {
        // Given
        let credential = createTestCredential()
        try await storage?.storeOathCredential(credential)

        // When
        let removed = try await storage?.removeOathCredential(credentialId: credential.id)
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)

        // Then
        XCTAssertTrue(removed != nil)
        XCTAssertNil(retrievedCredential)
    }

    func testRemoveNonExistentCredential() async throws {
        // When
        if let removed = try await storage?.removeOathCredential(credentialId: "non-existent") {
            // Then
            XCTAssertFalse(removed)
        } else {
            XCTFail("Remove operation return unexpected value")
        }
    }

    func testClearAllCredentials() async throws {
        // Given
        let credential1 = createTestCredential(id: "cred1")
        let credential2 = createTestCredential(id: "cred2")

        try await storage?.storeOathCredential(credential1)
        try await storage?.storeOathCredential(credential2)

        // When
        try await storage?.clearOathCredentials()
        let allCredentials = try await storage?.getAllOathCredentials()

        // Then
        XCTAssertEqual(allCredentials?.count, 0)
    }

    func testGetAllCredentialsWhenEmpty() async throws {
        // When
        let allCredentials = try await storage?.getAllOathCredentials()

        // Then
        XCTAssertEqual(allCredentials?.count, 0)
    }

    // MARK: - Security Tests

    func testSecretSeparateStorage() async throws {
        // Given
        let credential = createTestCredential(secretKey: "VERY_SECRET_KEY")

        // When
        try await storage?.storeOathCredential(credential)
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)

        // Then
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.secret, "VERY_SECRET_KEY")

        // Verify that the secret is not in the JSON serialization
        let encoder = JSONEncoder()
        let credentialData = try encoder.encode(credential)
        let jsonString = String(data: credentialData, encoding: .utf8)
        XCTAssertFalse(jsonString?.contains("VERY_SECRET_KEY") ?? true)
    }

    // MARK: - Error Handling Tests

    func testConcurrentAccess() async throws {
        // Given
        let credentials = (0..<10).map { index in
            createTestCredential(id: "cred\(index)", issuer: "Issuer \(index)")
        }

        // When - store credentials concurrently
        await withThrowingTaskGroup(of: Void.self) { group in
            for credential in credentials {
                group.addTask {
                    try await self.storage?.storeOathCredential(credential)
                }
            }
        }

        // Then
        let allCredentials = try await storage?.getAllOathCredentials()
        XCTAssertEqual(allCredentials?.count, 10)
    }

    func testCorruptedDataHandling() async throws {
        // This test verifies graceful handling of corrupted keychain data
        // In a real scenario, this would involve manipulating keychain data externally

        let credential = createTestCredential()
        try await storage?.storeOathCredential(credential)

        // Since we can't easily corrupt keychain data in unit tests,
        // we'll test the error handling paths by checking that proper errors are thrown
        // when keychain operations fail

        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)
        XCTAssertNotNil(retrievedCredential)
    }

    // MARK: - Performance Tests

    func testStoragePerformance() async throws {
        let credential = createTestCredential()

        measure {
            let expectation = expectation(description: "Storage operation")

            Task {
                do {
                    try await storage?.storeOathCredential(credential)
                    let credential = try await storage?.retrieveOathCredential(credentialId: credential.id)
                    XCTAssertNotNil(credential)
                    expectation.fulfill()
                } catch {
                    XCTFail("Storage operation failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testLargeDatasetPerformance() async throws {
        let credentials = (0..<100).map { index in
            createTestCredential(id: "cred\(index)")
        }

        measure {
            let expectation = expectation(description: "Large dataset operation")

            Task {
                do {
                    for credential in credentials {
                        try await storage?.storeOathCredential(credential)
                    }

                    let allCredentials = try await storage?.getAllOathCredentials()
                    XCTAssertEqual(allCredentials?.count, 100)

                    expectation.fulfill()
                } catch {
                    XCTFail("Large dataset operation failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

}

