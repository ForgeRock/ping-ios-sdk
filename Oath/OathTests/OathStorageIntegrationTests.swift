//
//  OathStorageIntegrationTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingLogger
@testable import PingOath

/// Integration tests for OATH storage implementations.
/// These tests verify the storage layer works with real keychain operations.
final class OathStorageIntegrationTests: XCTestCase {

    private var testLogger: TestLogger?
    private var storage: OathKeychainStorage?
    private let testServicePrefix = "com.pingidentity.oath.integration.test"

    override func setUpWithError() throws {
        try super.setUpWithError()

        testLogger = TestLogger()
        
        // Use unique service name for each test to avoid conflicts
        let testServiceName = "\(testServicePrefix).\(UUID().uuidString)"
        storage = OathKeychainStorage(
            service: testServiceName,
            logger: testLogger
        )
    }

    override func tearDownWithError() throws {
        // Clean up test data
        if let storage = storage {
            Task {
                try? await storage.clearOathCredentials()
            }
        }

        storage = nil
        try super.tearDownWithError()
    }

    // MARK: - Integration Test Helpers

    private func createRealWorldCredential() -> OathCredential {
        return OathCredential(
            id: "test-\(UUID().uuidString)",
            userId: "user123",
            resourceId: "device456",
            issuer: "GitHub",
            accountName: "developer@company.com",
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 6,
            period: 30,
            imageURL: "https://github.com/logo.png",
            backgroundColor: "#24292e",
            secretKey: "JBSWY3DPEHPK3PXP"
        )
    }

    // MARK: - Real Keychain Integration Tests

    func testRealKeychainStorageLifecycle() async throws {
        // Given
        let credential = createRealWorldCredential()

        // Test: Store credential
        try await storage?.storeOathCredential(credential)

        // Test: Retrieve credential
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.id, credential.id)
        XCTAssertEqual(retrievedCredential?.secret, credential.secret)

        // Test: Update credential
        let updatedCredential = OathCredential(
            id: credential.id,
            userId: credential.userId,
            resourceId: credential.resourceId,
            issuer: "GitHub Updated",
            accountName: credential.accountName,
            oathType: credential.oathType,
            oathAlgorithm: credential.oathAlgorithm,
            digits: credential.digits,
            period: credential.period,
            counter: credential.counter,
            createdAt: credential.createdAt,
            imageURL: credential.imageURL,
            backgroundColor: credential.backgroundColor,
            secretKey: credential.secret
        )

        try await storage?.storeOathCredential(updatedCredential)
        let reRetrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)
        XCTAssertEqual(reRetrievedCredential?.issuer, "GitHub Updated")

        // Test: Remove credential
        if let removed = try await storage?.removeOathCredential(credentialId: credential.id) {
            XCTAssertTrue(removed)
        } else {
            XCTFail("Failed to remove credential during cleanup")
        }

        let finalRetrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)
        XCTAssertNil(finalRetrievedCredential)
    }

    func testMultipleCredentialsInRealKeychain() async throws {
        // Given
        let credentials = [
            createRealWorldCredential(),
            createRealWorldCredential(),
            createRealWorldCredential()
        ]

        // When: Store all credentials
        for credential in credentials {
            try await storage?.storeOathCredential(credential)
        }

        // Then: Retrieve all credentials
        if let allCredentials = try await storage?.getAllOathCredentials() {
            XCTAssertEqual(allCredentials.count, 3)

            let storedIds = Set(allCredentials.map { $0.id })
            let originalIds = Set(credentials.map { $0.id })
            XCTAssertEqual(storedIds, originalIds)
        } else {
            XCTFail("Failed to retrieve all credentials")
        }

        // Test: Clear all credentials
        try await storage?.clearOathCredentials()
        let clearedCredentials = try await storage?.getAllOathCredentials()
        XCTAssertEqual(clearedCredentials?.count, 0)
    }

    func testKeychainDataPersistence() async throws {
        // Given
        let testServiceName = "\(testServicePrefix).persistence-test"
        let persistentStorage = OathKeychainStorage(service: testServiceName)
        let credential = createRealWorldCredential()

        // Store credential
        try await persistentStorage.storeOathCredential(credential)

        // Create new storage instance (simulates app restart)
        let newStorage = OathKeychainStorage(service: testServiceName)

        // Test: Data should persist across storage instances
        let persistedCredential = try await newStorage.retrieveOathCredential(credentialId: credential.id)
        XCTAssertNotNil(persistedCredential)
        XCTAssertEqual(persistedCredential?.id, credential.id)
        XCTAssertEqual(persistedCredential?.secret, credential.secret)

        // Cleanup with new instance
        let removed = try await newStorage.removeOathCredential(credentialId: credential.id)
        XCTAssertTrue(removed)
    }

    func testSecretSecurityInKeychain() async throws {
        // Given
        let sensitiveSecret = "SUPER_SECRET_KEY_123456"
        let credential = OathCredential(
            id: "security-test",
            issuer: "Test Security",
            accountName: "test@security.com",
            oathType: .totp,
            secretKey: sensitiveSecret
        )

        // When
        try await storage?.storeOathCredential(credential)
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)

        // Then
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.secret, sensitiveSecret)

        // Verify that credential can be JSON encoded without exposing secret
        let encoder = JSONEncoder()
        let credentialData = try encoder.encode(credential)
        let jsonString = String(data: credentialData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertFalse(jsonString?.contains(sensitiveSecret) ?? true)

        // Cleanup
        if let removed = try await storage?.removeOathCredential(credentialId: credential.id) {
            XCTAssertTrue(removed)
        } else {
            XCTFail("Failed to remove credential during cleanup")
        }
    }

    func testConcurrentKeychainOperations() async throws {
        // Given
        let credentials = (0..<20).map { index in
            var credential = createRealWorldCredential()
            credential = OathCredential(
                id: "concurrent-\(index)",
                issuer: credential.issuer,
                accountName: credential.accountName,
                oathType: credential.oathType,
                secretKey: credential.secret
            )
            return credential
        }

        // When: Perform concurrent operations
        await withThrowingTaskGroup(of: Void.self) { group in
            // Store credentials concurrently
            for credential in credentials {
                group.addTask {
                    try await self.storage?.storeOathCredential(credential)
                }
            }
        }

        // Then: Verify all credentials were stored
        let allCredentials = try await storage?.getAllOathCredentials()
        XCTAssertEqual(allCredentials?.count, 20)

        // Concurrent retrieval
        try await withThrowingTaskGroup(of: OathCredential?.self) { group in
            for credential in credentials {
                group.addTask {
                    return try await self.storage?.retrieveOathCredential(credentialId: credential.id)
                }
            }

            var retrievedCount = 0
            for try await retrievedCredential in group {
                if retrievedCredential != nil {
                    retrievedCount += 1
                }
            }
            XCTAssertEqual(retrievedCount, 20)
        }

        // Cleanup
        try await storage?.clearOathCredentials()
    }

    func testLargeCredentialDataInKeychain() async throws {
        // Given: Credential with large data
        let largeImageURL = String(repeating: "https://example.com/very/long/path/to/image/", count: 100)
        let largePolicies = String(repeating: "{\"policy\": \"value\"}", count: 50)

        let largeCredential = OathCredential(
            id: "large-data-test",
            issuer: "Large Data Test",
            accountName: "user@example.com",
            oathType: .totp,
            imageURL: largeImageURL,
            policies: largePolicies,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        // When
        try await storage?.storeOathCredential(largeCredential)
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: largeCredential.id)

        // Then
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.imageURL, largeImageURL)
        XCTAssertEqual(retrievedCredential?.policies, largePolicies)

        // Cleanup
        if let removed = try await storage?.removeOathCredential(credentialId: largeCredential.id) {
            XCTAssertTrue(removed)
        } else {
            XCTFail("Failed to remove credential during cleanup")
        }
    }

    func testKeychainErrorHandling() async throws {
        // Test duplicate credential handling
        let credential = createRealWorldCredential()

        // Store credential
        try await storage?.storeOathCredential(credential)

        // Store same credential again (should update, not fail)
        try await storage?.storeOathCredential(credential)

        // Verify it exists
        let retrievedCredential = try await storage?.retrieveOathCredential(credentialId: credential.id)
        XCTAssertNotNil(retrievedCredential)

        // Cleanup
        if let removed = try await storage?.removeOathCredential(credentialId: credential.id) {
            XCTAssertTrue(removed)
        } else {
            XCTFail("Failed to remove credential during cleanup")
        }
    }

    // MARK: - Performance Tests

    func testKeychainStoragePerformance() async throws {
        let credentials = (0..<50).map { _ in createRealWorldCredential() }

        measure {
            let expectation = expectation(description: "Keychain performance test")

            Task {
                do {
                    // Store all credentials
                    for credential in credentials {
                        try await storage?.storeOathCredential(credential)
                    }

                    // Retrieve all credentials
                    let allCredentials = try await storage?.getAllOathCredentials()
                    XCTAssertEqual(allCredentials?.count, 50)

                    // Clean up
                    try await storage?.clearOathCredentials()

                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Logging Tests

    func testLoggingBehavior() async throws {
        // Given
        let credential = createRealWorldCredential()

        // When
        try await storage?.storeOathCredential(credential)

        // Then
        if let testLogger = testLogger {
            XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Storing OATH credential") })
            XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Successfully stored OATH credential") })
        } else {
            XCTFail("TestLogger not initialized")
        }
    }
}
