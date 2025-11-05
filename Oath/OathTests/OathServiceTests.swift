//
//  OathServiceTests.swift
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

final class OathServiceTests: XCTestCase {

    // MARK: - Test Properties

    private var inMemoryStorage: OathInMemoryStorage = OathInMemoryStorage()
    private var policyEvaluator: MfaPolicyEvaluator = MfaPolicyEvaluator.create()
    private var testLogger: TestLogger = TestLogger()
    private var oathService: OathService?

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
        inMemoryStorage = OathInMemoryStorage()
        policyEvaluator = MfaPolicyEvaluator.create()
        testLogger = TestLogger()

        let configuration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = false
        }

        oathService = OathService(
            configuration: configuration,
            policyEvaluator: policyEvaluator
        )
    }

    override func tearDown() async throws {
        oathService = nil
        try await super.tearDown()
    }

    // MARK: - URI Operations Tests

    func testParseUri() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        let credential = try await service.parseUri(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(credential.oathType, .totp)
    }

    func testParseInvalidUri() async {
        let invalidUri = "invalid-uri"

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        do {
            _ = try await service.parseUri(invalidUri)
            XCTFail("Expected error for invalid URI")
        } catch {
            XCTAssertTrue(error is OathError)
        }
    }

    func testFormatUri() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }
        let uri = try await service.formatUri(credential)

        XCTAssertTrue(uri.hasPrefix("otpauth://totp/"))
        XCTAssertTrue(uri.contains("secret=JBSWY3DPEHPK3PXP"))
        XCTAssertTrue(uri.contains("issuer=Example"))
    }

    // MARK: - Credential Management Tests

    func testAddCredential() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        let storedCredential = try await service.addCredential(credential)

        XCTAssertEqual(storedCredential.issuer, credential.issuer)
        XCTAssertEqual(storedCredential.accountName, credential.accountName)

        let credentialCount = await inMemoryStorage.credentialCount
        XCTAssertEqual(credentialCount, 1)
    }

    func testAddCredentialWithPolicyViolation() async throws {
        // Create a mock policy that always fails
        let failingPolicy = MockFailingPolicy()
        let failingEvaluator = MfaPolicyEvaluator.create { config in
            config.policies = [failingPolicy]
        }
        
        let configuration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = false
        }
        
        let serviceWithFailingPolicy = OathService(
            configuration: configuration,
            policyEvaluator: failingEvaluator
        )
        
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            policies: "{\"mockFailing\": {}}",
            secretKey: "JBSWY3DPEHPK3PXP"
        )
        
        // Runtime policy failure should LOCK the credential but still add it
        let storedCredential = try await serviceWithFailingPolicy.addCredential(credential)
        XCTAssertNotNil(storedCredential)
        XCTAssertTrue(storedCredential.isLocked, "Credential should be locked due to policy failure")
        XCTAssertEqual(storedCredential.lockingPolicy, "mockFailing")
        
        // Should still be stored
        let credentialCount = await inMemoryStorage.credentialCount
        XCTAssertEqual(credentialCount, 1)
    }
    
    func testParseUriWithPolicyViolationBlocks() async {
        // Create a mock policy that always fails
        let failingPolicy = MockFailingPolicy()
        let failingEvaluator = MfaPolicyEvaluator.create { config in
            config.policies = [failingPolicy]
        }
        
        let configuration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = false
        }
        
        let serviceWithFailingPolicy = OathService(
            configuration: configuration,
            policyEvaluator: failingEvaluator
        )
        
        // Use mfauth scheme with policies parameter (base64 encoded JSON: {"mockFailing": {}})
        let uri = "mfauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=RXhhbXBsZQ&policies=eyJtb2NrRmFpbGluZyI6IHt9fQ=="
        
        // Registration-time policy failure should BLOCK completely
        do {
            _ = try await serviceWithFailingPolicy.parseUri(uri)
            XCTFail("Expected policyViolation error during registration")
        } catch let error as OathError {
            if case .policyViolation(let message, _) = error {
                XCTAssertTrue(message.contains("cannot be registered"), "Error should mention registration blocking")
            } else {
                XCTFail("Expected policyViolation error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCredentialUnlocksWhenPolicyPasses() async throws {
        // Create a togglable policy
        let togglablePolicy = MockTogglablePolicy(shouldPass: false)
        let togglableEvaluator = MfaPolicyEvaluator.create { config in
            config.policies = [togglablePolicy]
        }
        
        let configuration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = false
        }
        
        let serviceWithTogglablePolicy = OathService(
            configuration: configuration,
            policyEvaluator: togglableEvaluator
        )
        
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            policies: "{\"mockTogglable\": {}}",
            secretKey: "JBSWY3DPEHPK3PXP"
        )
        
        // Add credential with failing policy - should be locked
        let lockedCredential = try await serviceWithTogglablePolicy.addCredential(credential)
        XCTAssertTrue(lockedCredential.isLocked, "Credential should be locked initially")
        
        // Now make policy pass
        togglablePolicy.shouldPass = true
        
        // Retrieve credentials - should trigger policy re-evaluation and unlock
        let credentials = try await serviceWithTogglablePolicy.getCredentials()
        XCTAssertEqual(credentials.count, 1)
        
        let unlockedCredential = credentials[0]
        XCTAssertFalse(unlockedCredential.isLocked, "Credential should be unlocked when policy passes")
        XCTAssertNil(unlockedCredential.lockingPolicy, "Locking policy should be cleared")
    }

    func testGetCredentials() async throws {
        let credential1 = OathCredential(
            issuer: "Example1",
            accountName: "user1@example.com",
            oathType: .totp,
            secretKey: "SECRET1"
        )
        let credential2 = OathCredential(
            issuer: "Example2",
            accountName: "user2@example.com",
            oathType: .hotp,
            secretKey: "SECRET2"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add credentials to storage
        try await inMemoryStorage.storeOathCredential(credential1)
        try await inMemoryStorage.storeOathCredential(credential2)

        let credentials = try await service.getCredentials()

        XCTAssertEqual(credentials.count, 2)
    }

    func testGetCredential() async throws {
        let credential = OathCredential(
            id: "test-id",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        let retrievedCredential = try await service.getCredential(credentialId: "test-id")

        XCTAssertNotNil(retrievedCredential)
        XCTAssertEqual(retrievedCredential?.id, "test-id")
    }

    func testGetCredentialNotFound() async throws {
        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        let retrievedCredential = try await service.getCredential(credentialId: "nonexistent")

        XCTAssertNil(retrievedCredential)
    }

    func testRemoveCredential() async throws {
        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add a credential first
        let credential = OathCredential(
            id: "test-id",
            issuer: "Test",
            accountName: "test@example.com",
            oathType: .totp,
            secretKey: "SECRET"
        )
        try await inMemoryStorage.storeOathCredential(credential)

        let removed = try await service.removeCredential(credentialId: "test-id")

        XCTAssertTrue(removed)
    }

    func testRemoveCredentialNotFound() async throws {
        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        let removed = try await service.removeCredential(credentialId: "nonexistent")

        XCTAssertFalse(removed)
    }

    // MARK: - Code Generation Tests

    func testGenerateCodeForUnlockedCredential() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        let codeInfo = try await service.generateCode(for: credential)

        XCTAssertFalse(codeInfo.code.isEmpty)
        XCTAssertEqual(codeInfo.code.count, 6) // Default digits
    }

    func testGenerateCodeForLockedCredential() async {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            isLocked: true,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        do {
            _ = try await service.generateCode(for: credential)
            XCTFail("Expected credentialLocked error")
        } catch let error as OathError {
            if case .credentialLocked(let credentialId) = error {
                XCTAssertEqual(credentialId, credential.id)
            } else {
                XCTFail("Expected credentialLocked error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateCodeForCredentialById() async throws {
        let credential = OathCredential(
            id: "test-id",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        let codeInfo = try await service.generateCodeForCredential(credentialId: "test-id")

        XCTAssertFalse(codeInfo.code.isEmpty)
    }

    func testGenerateCodeForNonexistentCredential() async {
        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        do {
            _ = try await service.generateCodeForCredential(credentialId: "nonexistent")
            XCTFail("Expected credentialNotFound error")
        } catch let error as OathError {
            if case .credentialNotFound(let credentialId) = error {
                XCTAssertEqual(credentialId, "nonexistent")
            } else {
                XCTFail("Expected credentialNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateCodeForHotpUpdatesCounter() async throws {
        let credential = OathCredential(
            id: "hotp-test",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .hotp,
            counter: 5,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        let codeInfo = try await service.generateCodeForCredential(credentialId: "hotp-test")

        XCTAssertFalse(codeInfo.code.isEmpty)
        XCTAssertEqual(codeInfo.counter, 6) // Should be incremented
    }

    // MARK: - Caching Tests

    func testCachingEnabled() async throws {
        // Create service with caching enabled
        let cachingConfiguration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = true
        }

        let cachingService = OathService(
            configuration: cachingConfiguration,
            policyEvaluator: policyEvaluator
        )

        let credential = OathCredential(
            id: "cached-test",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        // First call should hit storage and cache the result
        let firstResult = try await cachingService.getCredential(credentialId: "cached-test")
        XCTAssertNotNil(firstResult)

        // Second call should hit cache (we can't easily verify this without access to internal state)
        let secondResult = try await cachingService.getCredential(credentialId: "cached-test")
        XCTAssertNotNil(secondResult)
    }

    func testClearCache() async throws {
        let cachingConfiguration = OathConfiguration.build { config in
            config.storage = inMemoryStorage
            config.logger = testLogger
            config.enableCredentialCache = true
        }

        let cachingService = OathService(
            configuration: cachingConfiguration,
            policyEvaluator: policyEvaluator
        )

        let credential = OathCredential(
            id: "cache-clear-test",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        // Populate cache
        _ = try await cachingService.getCredential(credentialId: "cache-clear-test")

        // Clear cache
        await cachingService.clearCache()

        // Next call should work (cache behavior is internal)
        let result = try await cachingService.getCredential(credentialId: "cache-clear-test")
        XCTAssertNotNil(result)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentCredentialAccess() async throws {
        let credential = OathCredential(
            id: "concurrent-test",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Add credential to storage
        try await inMemoryStorage.storeOathCredential(credential)

        // Perform multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await service.getCredential(credentialId: "concurrent-test")
                    } catch {
                        XCTFail("Concurrent access failed: \(error)")
                    }
                }
            }
        }

        // Should complete without data races or crashes
        XCTAssertTrue(true) // Test passes if no crashes occur
    }

    // MARK: - Error Handling Tests

    func testNormalOperationsWork() async throws {
        guard let service = oathService else {
            XCTFail("OathService not initialized")
            return
        }

        // Test that normal operations work with real implementations
        let credentials = try await service.getCredentials()
        XCTAssertNotNil(credentials)
        XCTAssertEqual(credentials.count, 0) // Empty storage initially
    }
}

// MARK: - Mock Policies for Testing

/// Mock policy that always fails for testing policy violations
private struct MockFailingPolicy: MfaPolicy, Sendable {
    var name: String { "mockFailing" }
    
    func evaluate(data: [String: Any]?) async throws -> Bool {
        return false
    }
}

/// Mock policy that can be toggled between pass/fail for testing unlocking
private class MockTogglablePolicy: MfaPolicy, @unchecked Sendable {
    var name: String { "mockTogglable" }
    var shouldPass: Bool
    
    init(shouldPass: Bool) {
        self.shouldPass = shouldPass
    }
    
    func evaluate(data: [String: Any]?) async throws -> Bool {
        return shouldPass
    }
}
