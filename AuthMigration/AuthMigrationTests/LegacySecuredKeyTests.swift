//
//  LegacySecuredKeyTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import Security
@testable import PingAuthMigration

final class LegacySecuredKeyTests: XCTestCase {

    private let testTag = "com.pingidentity.test.securedKey.\(UUID().uuidString)"

    override func tearDown() {
        super.tearDown()
        // Clean up any test keys
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: testTag.data(using: .utf8)!
        ]
        SecItemDelete(query as CFDictionary)
    }

    func testLoad_returnsNilWhenNoKeyExists() {
        let key = LegacySecuredKey.load(applicationTag: "com.nonexistent.key.tag.\(UUID().uuidString)")
        XCTAssertNil(key)
    }

    func testLoad_returnsKeyWhenExists() throws {
        // Create a non-SE EC key for testing (SE not available on simulator)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: testTag.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            // On some environments key creation may fail — skip gracefully
            throw XCTSkip("Cannot create EC key in this environment")
        }

        let loaded = LegacySecuredKey.load(applicationTag: testTag)
        XCTAssertNotNil(loaded)
    }

    func testDecrypt_failsWithInvalidData() throws {
        // Create a test key
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: testTag.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            throw XCTSkip("Cannot create EC key in this environment")
        }

        guard let key = LegacySecuredKey.load(applicationTag: testTag) else {
            XCTFail("Expected key to be loaded")
            return
        }

        // Decrypting random data should return nil (matching legacy fallback behavior)
        let randomData = Data([0x01, 0x02, 0x03, 0x04])
        let result = key.decrypt(randomData)
        XCTAssertNil(result, "Decrypting invalid data should return nil")
    }
}
