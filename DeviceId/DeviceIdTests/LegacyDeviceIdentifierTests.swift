//
//  LegacyDeviceIdentifierTests.swift
//  DeviceIdTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CommonCrypto
@testable import PingDeviceId

/// Unit tests for LegacyDeviceIdentifier actor
final class LegacyDeviceIdentifierTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        await cleanupLegacyKeychain()
    }
    
    override func tearDown() async throws {
        await cleanupLegacyKeychain()
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupLegacyKeychain() async {
        let keys = [
            LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
            LegacyDeviceIdentifier.LegacyKeychainKeys.privateKeyData
        ]
        
        for key in keys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
    
    private func storeLegacyIdentifier(_ identifier: String) {
        guard let data = identifier.data(using: .utf8) else {
            XCTFail("Failed to encode identifier")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess, "Failed to store legacy identifier")
    }
    
    private func storeLegacyPublicKeyData(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess, "Failed to store legacy public key data")
    }
    
    private func generateLegacyHash(from data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(bytes: digest, count: digest.count).toHexString()
    }
    
    // MARK: - Tests
    
    func testGetLegacyIdentifier_WhenExists_ReturnsIdentifier() async throws {
        // Given
        let expectedIdentifier = "legacy-test-identifier-12345"
        storeLegacyIdentifier(expectedIdentifier)
        
        let legacyIdentifier = LegacyDeviceIdentifier()
        
        // When
        let result = try await legacyIdentifier.getLegacyIdentifier()
        
        // Then
        XCTAssertEqual(result, expectedIdentifier)
    }
    
    func testGetLegacyIdentifier_WhenNotExists_ReturnsNil() async throws {
        // Given
        let legacyIdentifier = LegacyDeviceIdentifier()
        
        // When
        let result = try await legacyIdentifier.getLegacyIdentifier()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testMigrateLegacyIdentifierFromPublicKey_WhenPublicKeyExists_RegeneratesIdentifier() async throws {
        // Given
        let testData = "test-public-key-data".data(using: .utf8)!
        storeLegacyPublicKeyData(testData)
        
        let expectedHash = generateLegacyHash(from: testData)
        let legacyIdentifier = LegacyDeviceIdentifier()
        
        // When
        let result = try await legacyIdentifier.migrateLegacyIdentifierFromPublicKey()
        
        // Then
        XCTAssertEqual(result, expectedHash)
        
        // Verify it was also saved
        let savedId = try await legacyIdentifier.getLegacyIdentifier()
        XCTAssertEqual(savedId, expectedHash)
    }
    
    func testMigrateLegacyIdentifierFromPublicKey_WhenPublicKeyNotExists_ReturnsNil() async throws {
        // Given
        let legacyIdentifier = LegacyDeviceIdentifier()
        
        // When
        let result = try await legacyIdentifier.migrateLegacyIdentifierFromPublicKey()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testLegacyKeychainKeys_MatchFRAuthSDK() {
        // Verify the legacy keys match FRAuth SDK exactly
        XCTAssertEqual(
            LegacyDeviceIdentifier.LegacyKeychainKeys.identifier,
            "com.forgerock.ios.device-identifier.hash-base64-string-identifier"
        )
        XCTAssertEqual(
            LegacyDeviceIdentifier.LegacyKeychainKeys.publicKeyData,
            "com.forgerock.ios.device-identifier.pubic-key.data"
        )
        XCTAssertEqual(
            LegacyDeviceIdentifier.LegacyKeychainKeys.privateKeyData,
            "com.forgerock.ios.device-identifier.private-key.data"
        )
    }
    
    func testHashAlgorithm_MatchesLegacyImplementation() async throws {
        // Given: Test data
        let testData = "test-data-for-hashing".data(using: .utf8)!
        
        // Expected hash from legacy implementation (SHA-1)
        var expectedDigest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        testData.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(testData.count), &expectedDigest)
        }
        let expectedHash = Data(bytes: expectedDigest, count: expectedDigest.count).toHexString()
        
        // When: Using legacy identifier to hash
        storeLegacyPublicKeyData(testData)
        let legacyIdentifier = LegacyDeviceIdentifier()
        let result = try await legacyIdentifier.migrateLegacyIdentifierFromPublicKey()
        
        // Then
        XCTAssertEqual(result, expectedHash)
        XCTAssertEqual(result?.count, 40, "SHA-1 hash should be 40 hex characters")
    }
}

extension Data {
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
