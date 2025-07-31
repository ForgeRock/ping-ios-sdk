//
//  DeviceTests.swift
//  DeviceTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingDeviceId
import PingStorage

/// Tests for the DeviceIdentifier functionality, including both the default implementation and the test stub.
final class DeviceTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        // Ensure a clean slate before each test by deleting any previously
        // persisted identifiers. This prevents tests from interfering with each other.
        let group = DispatchGroup()
        
        group.enter()
        Task {
            // Access the internal property directly
            try? await DefaultDeviceIdentifier(configuration: .default).keychainService.delete()
            group.leave()
        }
        
        group.enter()
        Task {
            try? await DefaultDeviceIdentifier(configuration: .highSecurity).keychainService.delete()
            group.leave()
        }
        
        group.wait()
    }

    override func tearDownWithError() throws {
        // Clean up after each test to leave the keychain in a neutral state.
        let group = DispatchGroup()
        
        group.enter()
        Task {
            try? await DefaultDeviceIdentifier(configuration: .default).keychainService.delete()
            group.leave()
        }
        
        group.enter()
        Task {
            try? await DefaultDeviceIdentifier(configuration: .highSecurity).keychainService.delete()
            group.leave()
        }
        
        group.wait()
    }
    
    // MARK: - Existing Tests
    
    func testIdentifierProtocolUse() async {
        let deviceIdentifier = TestDeviceIdentifier()
        
        // When
        let identifier = try? await deviceIdentifier.id
        
        // Then
        XCTAssertNotNil(identifier)
        XCTAssertEqual(identifier?.count, 36, "UUID string should be 36 characters")
        
        let identifier2 = try? await deviceIdentifier.id
        XCTAssertEqual(identifier, identifier2, "TestDeviceIdentifier should return the same UUID each time")
    }
    
    func testDefaultDeviceIdentifier() async throws {
        let deviceIdentifier = try DefaultDeviceIdentifier()
        
        let identifier1 = try await deviceIdentifier.id
        XCTAssertFalse(identifier1.isEmpty, "Device identifier should not be empty")
        
        let identifier2 = try await deviceIdentifier.id
        XCTAssertEqual(identifier1, identifier2, "Identifier should be stable across calls")
        XCTAssertEqual(identifier2.count, 64, "SHA-256 hex should be 64 characters")
        
        let deviceIdProvider: DeviceIdentifier = deviceIdentifier
        let identifier3 = try await deviceIdProvider.id
        XCTAssertEqual(identifier1, identifier3, "Protocol access should yield the same identifier")
    }
    
    func testDataToHexString() {
        let raw = Data([0x00, 0xAB, 0xFF])
        let hex = raw.toHexString()
        XCTAssertEqual(hex, "00abff", "toHexString() should produce lowercase hex with no prefixes")
    }
    
    func testHashSHA256AndTransformToHex() {
        // SHA256("abc") in hex is:
        let expected =
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        
        let helper = TestDeviceIdentifier()
        let computed = helper.hashSHA256AndTransformToHex(Data("abc".utf8))
        XCTAssertEqual(computed, expected,
                       "hashSHA256AndTransformToHex should match known SHA-256 digest")
    }
    
    func testDefaultIdentifierCrossInstance() async throws {
        // First instance writes to keychain
        let id1 = try await DefaultDeviceIdentifier().id
        
        // New actor instance should read the same saved value
        let id2 = try await DefaultDeviceIdentifier().id
        XCTAssertEqual(id1, id2,
                       "Separate DefaultDeviceIdentifier instances must load the same persisted id")
    }
    
    func testConcurrentAccess() async throws {
        let deviceIdentifier = try DefaultDeviceIdentifier()
        
        // Spin up multiple concurrent requests
        let ids = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await deviceIdentifier.id }
            }
            var results = [String]()
            for try await id in group {
                results.append(id)
            }
            return results
        }
        
        // All should be identical
        let unique = Set(ids)
        XCTAssertEqual(unique.count, 1,
                       "Concurrent calls should all return the same identifier without race")
    }
    
    func testTestDeviceIdentifierUniqueness() async throws {
        // Each new TestDeviceIdentifier() has its own random UUID
        let id1 = try await TestDeviceIdentifier().id
        let id2 = try await TestDeviceIdentifier().id
        XCTAssertNotEqual(id1, id2,
                          "Two different TestDeviceIdentifier instances should yield different UUIDs")
    }
    
    // MARK: - New and Improved Tests
    
    /// Tests that the `regenerateIdentifier` function correctly creates a new, stable identifier.
    func testRegenerateIdentifier() async throws {
        // Given
        let deviceIdentifier = try DefaultDeviceIdentifier()
        let id1 = try await deviceIdentifier.id
        
        // When
        let id2 = try await deviceIdentifier.regenerateIdentifier()
        
        // Then
        XCTAssertNotEqual(id1, id2, "Regenerated identifier should be different from the original.")
        XCTAssertEqual(id2.count, 64, "New identifier should be a valid SHA-256 hash.")
        
        // Verify the new identifier is stable
        let id3 = try await deviceIdentifier.id
        XCTAssertEqual(id2, id3, "The new identifier should be persisted and stable after regeneration.")
    }

    /// Tests that using different configurations results in different keychain accounts and thus different identifiers.
    func testDifferentConfigurationsYieldDifferentIDs() async throws {
        // Given two separate instances with different configurations
        let defaultIdProvider = try DefaultDeviceIdentifier(configuration: .default)
        let secureIdProvider = try DefaultDeviceIdentifier(configuration: .highSecurity)
        
        // When
        let defaultId = try await defaultIdProvider.id
        let secureId = try await secureIdProvider.id
        
        // Then
        XCTAssertNotEqual(defaultId, secureId, "Identifiers from different configurations should not match.")
        XCTAssertEqual(defaultId.count, 64)
        XCTAssertEqual(secureId.count, 64)
    }

    /// Tests the critical fallback path where key generation fails.
    /// The system should fall back to a UUID-based identifier instead of crashing.
    func testIdentifierFallbackOnKeyGenerationFailure() async throws {
        // Given a configuration with an invalid key size, which will cause SecKeyCreateRandomKey to fail
        let failingConfig = DeviceIdentifierConfiguration(keySize: 0, keychainAccount: "com.pingidentity.test.failing")
        let deviceIdentifier = try DefaultDeviceIdentifier(configuration: failingConfig)

        // When
        // This call should not throw, because the failure is caught and handled by the fallback mechanism.
        let fallbackId = try await deviceIdentifier.id

        // Then
        XCTAssertNotNil(fallbackId, "A fallback identifier should be generated.")
        XCTAssertEqual(fallbackId.count, 64, "Fallback identifier should be a SHA-256 hash.")
        
        // Verify the fallback ID is stable
        let fallbackId2 = try await deviceIdentifier.id
        XCTAssertEqual(fallbackId, fallbackId2, "The fallback identifier should be stable.")
    }
}


// MARK: - Test Support & Helpers

/// Simple stub conforming to `DeviceIdentifier` that
/// returns a fixed UUID string on init, so we can test
/// protocol conformance and our hash helper.
final class TestDeviceIdentifier: DeviceIdentifier {
    private let identifier = UUID().uuidString
    
    var id: String {
        get async throws {
            identifier
        }
    }
    
    /// Expose the hash helper for ease of testing
    func hashSHA256AndTransformToHex(_ data: Data) -> String {
        // from protocol extension
        (self as DeviceIdentifier).hashSHA256AndTransformToHex(data)
    }
}

fileprivate extension Data {
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
