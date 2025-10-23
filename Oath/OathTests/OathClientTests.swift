//
//  OathClientTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath
@testable import PingMfaCommons
@testable import PingLogger

final class OathClientTests: XCTestCase {

    // MARK: - Test Properties

    private var testLogger: TestLogger = TestLogger()
    private var oathClient: OathClient?

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
        testLogger = TestLogger()
    }

    override func tearDown() async throws {
        if let client = oathClient {
            try await client.close()
        }
        oathClient = nil
        try await super.tearDown()
    }

    // MARK: - Factory Method Tests

    func testCreateClientWithDefaultConfiguration() async throws {
        oathClient = try await OathClient.createClient()
        XCTAssertNotNil(oathClient)
    }

    func testCreateClientWithCustomConfiguration() async throws {
        let inMemoryStorage = OathInMemoryStorage()

        oathClient = try await OathClient.createClient { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = true
            config.encryptionEnabled = false
        }

        XCTAssertNotNil(oathClient)
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("OATH client initialized successfully") })
    }

    func testCreateClientWithInvalidConfiguration() async throws {
        // Test client creation with potentially problematic configuration
        oathClient = try await OathClient.createClient { config in
            config.timeoutMs = 0.0 // This should still work, but might not be ideal
            config.logger = testLogger
        }

        XCTAssertNotNil(oathClient)
    }

    // MARK: - Credential Management Tests

    func testAddCredentialFromValidTotpUri() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let credential = try await client.addCredentialFromUri(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertTrue(testLogger.infoMessages.contains { $0.contains("Successfully added credential: Example") })
    }

    func testAddCredentialFromValidHotpUri() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://hotp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=5"
        let credential = try await client.addCredentialFromUri(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.oathType, .hotp)
        XCTAssertEqual(credential.counter, 5)
    }

    func testAddCredentialFromInvalidUri() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let invalidUri = "invalid-uri-format"

        do {
            _ = try await client.addCredentialFromUri(invalidUri)
            XCTFail("Expected error for invalid URI")
        } catch let error as OathError {
            if case .invalidUri = error {
                // Expected error
                XCTAssertTrue(testLogger.errorMessages.contains { $0.contains("Failed to add credential from URI") })
            } else {
                XCTFail("Expected invalidUri error, got \(error)")
            }
        }
    }

    func testSaveCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let credential = OathCredential(
            issuer: "TestIssuer",
            accountName: "test@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let savedCredential = try await client.saveCredential(credential)

        XCTAssertEqual(savedCredential.issuer, credential.issuer)
        XCTAssertEqual(savedCredential.accountName, credential.accountName)
        XCTAssertTrue(testLogger.infoMessages.contains { $0.contains("Successfully saved credential") })
    }

    func testGetCredentials() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        // Initially should be empty
        let initialCredentials = try await client.getCredentials()
        XCTAssertEqual(initialCredentials.count, 0)

        // Add some credentials
        let uri1 = "otpauth://totp/Example1:user1@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example1"
        let uri2 = "otpauth://hotp/Example2:user2@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example2&counter=0"

        _ = try await client.addCredentialFromUri(uri1)
        _ = try await client.addCredentialFromUri(uri2)

        // Should now have 2 credentials
        let credentials = try await client.getCredentials()
        XCTAssertEqual(credentials.count, 2)
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Retrieved 2 credentials") })
    }

    func testGetCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let addedCredential = try await client.addCredentialFromUri(uri)

        // Retrieve the credential
        let retrievedCredential = try await client.getCredential(addedCredential.id)
        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.id, addedCredential.id)
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Found credential: \(addedCredential.id)") })

        // Try to get non-existent credential
        let nonExistentCredential = try await client.getCredential("non-existent-id")
        XCTAssertNil(nonExistentCredential)
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Credential not found: non-existent-id") })
    }

    func testDeleteCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let addedCredential = try await client.addCredentialFromUri(uri)

        // Delete the credential
        let deleted = try await client.deleteCredential(addedCredential.id)
        XCTAssertTrue(deleted)
        XCTAssertTrue(testLogger.infoMessages.contains { $0.contains("Successfully deleted credential: \(addedCredential.id)") })

        // Verify it's gone
        let retrievedCredential = try await client.getCredential(addedCredential.id)
        XCTAssertNil(retrievedCredential)

        // Try to delete non-existent credential
        let notDeleted = try await client.deleteCredential("non-existent-id")
        XCTAssertFalse(notDeleted)
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Credential not found for deletion: non-existent-id") })
    }

    // MARK: - Code Generation Tests

    func testGenerateCodeForTotpCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let credential = try await client.addCredentialFromUri(uri)

        let code = try await client.generateCode(credential.id)
        XCTAssertEqual(code.count, 6) // Default digits
        XCTAssertTrue(code.allSatisfy { $0.isNumber })
        XCTAssertTrue(testLogger.debugMessages.contains { $0.contains("Successfully generated code for credential: \(credential.id)") })
    }

    func testGenerateCodeForHotpCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let uri = "otpauth://hotp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=0"
        let credential = try await client.addCredentialFromUri(uri)

        let code = try await client.generateCode(credential.id)
        XCTAssertEqual(code.count, 6) // Default digits
        XCTAssertTrue(code.allSatisfy { $0.isNumber })

        // Generate another code - should increment counter
        let code2 = try await client.generateCode(credential.id)
        XCTAssertEqual(code2.count, 6)
        XCTAssertNotEqual(code, code2) // Should be different due to counter increment
    }

    func testGenerateCodeWithValidity() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        // Test TOTP
        let totpUri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let totpCredential = try await client.addCredentialFromUri(totpUri)

        let totpCodeInfo = try await client.generateCodeWithValidity(totpCredential.id)
        XCTAssertEqual(totpCodeInfo.code.count, 6)
        XCTAssertGreaterThan(totpCodeInfo.timeRemaining, 0)
        XCTAssertEqual(totpCodeInfo.totalPeriod, 30)
        XCTAssertEqual(totpCodeInfo.counter, -1) // Not applicable for TOTP

        // Test HOTP
        let hotpUri = "otpauth://hotp/Example:user2@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=5"
        let hotpCredential = try await client.addCredentialFromUri(hotpUri)

        let hotpCodeInfo = try await client.generateCodeWithValidity(hotpCredential.id)
        XCTAssertEqual(hotpCodeInfo.code.count, 6)
        XCTAssertEqual(hotpCodeInfo.counter, 6) // Should be incremented
        XCTAssertEqual(hotpCodeInfo.timeRemaining, -1) // Not applicable for HOTP
        XCTAssertEqual(hotpCodeInfo.totalPeriod, 0) // Not applicable for HOTP
    }

    func testGenerateCodeForNonExistentCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        do {
            _ = try await client.generateCode("non-existent-id")
            XCTFail("Expected credentialNotFound error")
        } catch let error as OathError {
            if case .credentialNotFound(let credentialId) = error {
                XCTAssertEqual(credentialId, "non-existent-id")
                XCTAssertTrue(testLogger.errorMessages.contains { $0.contains("Failed to generate code for credential non-existent-id") })
            } else {
                XCTFail("Expected credentialNotFound error, got \(error)")
            }
        }
    }

    func testGenerateCodeForLockedCredential() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            isLocked: true,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let savedCredential = try await client.saveCredential(credential)

        do {
            _ = try await client.generateCode(savedCredential.id)
            XCTFail("Expected credentialLocked error")
        } catch let error as OathError {
            if case .credentialLocked(let credentialId) = error {
                XCTAssertEqual(credentialId, savedCredential.id)
            } else {
                XCTFail("Expected credentialLocked error, got \(error)")
            }
        }
    }

    // MARK: - Lifecycle Tests

    func testClientClose() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
            config.enableCredentialCache = true
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        // Add a credential to populate cache
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        _ = try await client.addCredentialFromUri(uri)

        // Close the client
        try await client.close()
        XCTAssertTrue(testLogger.infoMessages.contains { $0.contains("OATH client closed successfully") })

        // Set to nil to indicate it's been closed
        oathClient = nil
    }

    // MARK: - Integration Tests

    func testCompleteCredentialLifecycle() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
            config.enableCredentialCache = true
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        // 1. Add credential from URI
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&digits=8"
        let credential = try await client.addCredentialFromUri(uri)
        XCTAssertEqual(credential.digits, 8)

        // 2. Verify it's stored
        let storedCredential = try await client.getCredential(credential.id)
        XCTAssertNotNil(storedCredential)
        XCTAssertEqual(storedCredential?.id, credential.id)

        // 3. Generate code
        let code = try await client.generateCode(credential.id)
        XCTAssertEqual(code.count, 8) // Custom digits
        XCTAssertTrue(code.allSatisfy { $0.isNumber })

        // 4. Get all credentials
        let allCredentials = try await client.getCredentials()
        XCTAssertEqual(allCredentials.count, 1)
        XCTAssertEqual(allCredentials.first?.id, credential.id)

        // 5. Update credential
        var updatedCredential = credential
        updatedCredential.displayIssuer = "Updated Example"
        let savedUpdated = try await client.saveCredential(updatedCredential)
        XCTAssertEqual(savedUpdated.displayIssuer, "Updated Example")

        // 6. Delete credential
        let deleted = try await client.deleteCredential(credential.id)
        XCTAssertTrue(deleted)

        // 7. Verify it's gone
        let deletedCredential = try await client.getCredential(credential.id)
        XCTAssertNil(deletedCredential)

        let finalCredentials = try await client.getCredentials()
        XCTAssertEqual(finalCredentials.count, 0)
    }

    func testConcurrentOperations() async throws {
        oathClient = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
            config.enableCredentialCache = true
        }

        guard let client = oathClient else {
            XCTFail("Failed to create client")
            return
        }

        // Add a credential
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let credential = try await client.addCredentialFromUri(uri)

        // Perform multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await client.generateCode(credential.id)
                        _ = try await client.getCredential(credential.id)
                    } catch {
                        XCTFail("Concurrent operation failed: \(error)")
                    }
                }
            }
        }

        // Should complete without issues
        XCTAssertTrue(true)
    }

    // MARK: - Error Handling Tests

    func testMultipleClientInstances() async throws {
        let client1 = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        let client2 = try await OathClient.createClient { config in
            config.storage = OathInMemoryStorage()
            config.logger = testLogger
        }

        // Each client should work independently
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let credential1 = try await client1.addCredentialFromUri(uri)
        let credential2 = try await client2.addCredentialFromUri(uri)

        // They should have different storage, so both should succeed
        XCTAssertNotNil(credential1)
        XCTAssertNotNil(credential2)

        try await client1.close()
        try await client2.close()
    }
}
