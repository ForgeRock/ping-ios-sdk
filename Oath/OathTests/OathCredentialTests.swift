//
//  OathCredentialTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class OathCredentialTests: XCTestCase {

    // MARK: - Test Data

    private let testSecretKey = "JBSWY3DPEHPK3PXP"
    private let testIssuer = "Example Corp"
    private let testAccountName = "user@example.com"
    private let testUserId = "user123"
    private let testResourceId = "device456"
    private let testId = "credential789"

    // MARK: - Initialization Tests

    func testInitializationWithRequiredParameters() {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        XCTAssertFalse(credential.id.isEmpty)
        XCTAssertEqual(credential.issuer, testIssuer)
        XCTAssertEqual(credential.displayIssuer, testIssuer)
        XCTAssertEqual(credential.accountName, testAccountName)
        XCTAssertEqual(credential.displayAccountName, testAccountName)
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
        XCTAssertEqual(credential.digits, 6)
        XCTAssertEqual(credential.period, 30)
        XCTAssertEqual(credential.counter, 0)
        XCTAssertFalse(credential.isLocked)
        XCTAssertNil(credential.userId)
        XCTAssertNil(credential.resourceId)
        XCTAssertNil(credential.imageURL)
        XCTAssertNil(credential.backgroundColor)
        XCTAssertNil(credential.policies)
        XCTAssertNil(credential.lockingPolicy)
    }

    func testInitializationWithAllParameters() {
        let createdAt = Date()
        let credential = OathCredential(
            id: testId,
            userId: testUserId,
            resourceId: testResourceId,
            issuer: testIssuer,
            displayIssuer: "Custom Display Issuer",
            accountName: testAccountName,
            displayAccountName: "Custom Display Account",
            oathType: .hotp,
            oathAlgorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 5,
            createdAt: createdAt,
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF0000",
            policies: "{\"policy\":\"value\"}",
            lockingPolicy: "BiometricPolicy",
            isLocked: true,
            secretKey: testSecretKey
        )

        XCTAssertEqual(credential.id, testId)
        XCTAssertEqual(credential.userId, testUserId)
        XCTAssertEqual(credential.resourceId, testResourceId)
        XCTAssertEqual(credential.issuer, testIssuer)
        XCTAssertEqual(credential.displayIssuer, "Custom Display Issuer")
        XCTAssertEqual(credential.accountName, testAccountName)
        XCTAssertEqual(credential.displayAccountName, "Custom Display Account")
        XCTAssertEqual(credential.oathType, .hotp)
        XCTAssertEqual(credential.oathAlgorithm, .sha256)
        XCTAssertEqual(credential.digits, 8)
        XCTAssertEqual(credential.period, 60)
        XCTAssertEqual(credential.counter, 5)
        XCTAssertEqual(credential.createdAt, createdAt)
        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(credential.backgroundColor, "#FF0000")
        XCTAssertEqual(credential.policies, "{\"policy\":\"value\"}")
        XCTAssertEqual(credential.lockingPolicy, "BiometricPolicy")
        XCTAssertTrue(credential.isLocked)
    }

    // MARK: - Computed Properties Tests

    func testComputedProperties() {
        let totpCredential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha256,
            secretKey: testSecretKey
        )

        XCTAssertEqual(totpCredential.type, "totp")
        XCTAssertEqual(totpCredential.algorithm, "SHA256")

        let hotpCredential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            oathAlgorithm: .sha512,
            secretKey: testSecretKey
        )

        XCTAssertEqual(hotpCredential.type, "hotp")
        XCTAssertEqual(hotpCredential.algorithm, "SHA512")
    }

    // MARK: - Validation Tests

    func testValidationSuccess() throws {
        let validCredential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha1,
            digits: 6,
            period: 30,
            secretKey: testSecretKey
        )

        XCTAssertNoThrow(try validCredential.validate())
    }

    func testValidationInvalidDigits() {
        let invalidDigitsLow = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            digits: 3,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try invalidDigitsLow.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Digits must be between 4 and 8"))
        }

        let invalidDigitsHigh = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            digits: 9,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try invalidDigitsHigh.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Digits must be between 4 and 8"))
        }
    }

    func testValidationInvalidPeriod() {
        let invalidPeriodZero = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            period: 0,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try invalidPeriodZero.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Period must be between 1 and 300 seconds"))
        }

        let invalidPeriodHigh = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            period: 301,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try invalidPeriodHigh.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Period must be between 1 and 300 seconds"))
        }
    }

    func testValidationInvalidCounter() {
        let invalidCounter = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            counter: -1,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try invalidCounter.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Counter must be non-negative"))
        }
    }

    func testValidationEmptySecretKey() {
        let emptySecret = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: ""
        )

        XCTAssertThrowsError(try emptySecret.validate()) { error in
            guard case OathError.invalidSecret(let message) = error else {
                XCTFail("Expected invalidSecret error")
                return
            }
            XCTAssertTrue(message.contains("Secret key cannot be empty"))
        }
    }

    func testValidationEmptyIssuer() {
        let emptyIssuer = OathCredential(
            issuer: "",
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try emptyIssuer.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Issuer cannot be empty"))
        }
    }

    func testValidationEmptyAccountName() {
        let emptyAccountName = OathCredential(
            issuer: testIssuer,
            accountName: "",
            oathType: .totp,
            secretKey: testSecretKey
        )

        XCTAssertThrowsError(try emptyAccountName.validate()) { error in
            guard case OathError.invalidParameterValue(let message) = error else {
                XCTFail("Expected invalidParameterValue error")
                return
            }
            XCTAssertTrue(message.contains("Account name cannot be empty"))
        }
    }

    // MARK: - Serialization Tests

    func testJSONSerialization() throws {
        let original = OathCredential(
            id: testId,
            userId: testUserId,
            resourceId: testResourceId,
            issuer: testIssuer,
            displayIssuer: "Custom Issuer",
            accountName: testAccountName,
            displayAccountName: "Custom Account",
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 0,
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF0000",
            policies: "{\"test\":\"policy\"}",
            lockingPolicy: "TestPolicy",
            isLocked: true,
            secretKey: testSecretKey
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(original)

        // Decode from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OathCredential.self, from: jsonData)

        // Verify all properties except secret key (which is intentionally not serialized)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.resourceId, original.resourceId)
        XCTAssertEqual(decoded.issuer, original.issuer)
        XCTAssertEqual(decoded.displayIssuer, original.displayIssuer)
        XCTAssertEqual(decoded.accountName, original.accountName)
        XCTAssertEqual(decoded.displayAccountName, original.displayAccountName)
        XCTAssertEqual(decoded.oathType, original.oathType)
        XCTAssertEqual(decoded.oathAlgorithm, original.oathAlgorithm)
        XCTAssertEqual(decoded.digits, original.digits)
        XCTAssertEqual(decoded.period, original.period)
        XCTAssertEqual(decoded.counter, original.counter)
        XCTAssertEqual(decoded.imageURL, original.imageURL)
        XCTAssertEqual(decoded.backgroundColor, original.backgroundColor)
        XCTAssertEqual(decoded.policies, original.policies)
        XCTAssertEqual(decoded.lockingPolicy, original.lockingPolicy)
        XCTAssertEqual(decoded.isLocked, original.isLocked)

        // Secret key should be empty after deserialization for security
        XCTAssertEqual(decoded.secretKey, "")
    }

    func testJSONSerializationExcludesSecretKey() throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(credential)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Verify secret key is not present in JSON
        XCTAssertNotNil(jsonString)
        XCTAssertFalse(jsonString?.contains(testSecretKey) ?? true)
        XCTAssertFalse(jsonString?.contains("secretKey") ?? true)
    }

    // MARK: - Internal Extension Tests

    func testWithSecretFactoryMethod() {
        let baseCredential = OathCredential(
            id: testId,
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: ""
        )

        let credentialWithSecret = OathCredential.withSecret(baseCredential, secretKey: testSecretKey)

        XCTAssertEqual(credentialWithSecret.id, baseCredential.id)
        XCTAssertEqual(credentialWithSecret.issuer, baseCredential.issuer)
        XCTAssertEqual(credentialWithSecret.accountName, baseCredential.accountName)
        XCTAssertEqual(credentialWithSecret.secretKey, testSecretKey)
        XCTAssertEqual(credentialWithSecret.secret, testSecretKey)
    }

    func testSecretPropertyAccess() {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        XCTAssertEqual(credential.secret, testSecretKey)
    }

    // MARK: - Edge Cases and Boundary Tests

    func testBoundaryValues() throws {
        // Test minimum valid digits
        let minDigits = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            digits: 4,
            secretKey: testSecretKey
        )
        XCTAssertNoThrow(try minDigits.validate())

        // Test maximum valid digits
        let maxDigits = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            digits: 8,
            secretKey: testSecretKey
        )
        XCTAssertNoThrow(try maxDigits.validate())

        // Test minimum valid period
        let minPeriod = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            period: 1,
            secretKey: testSecretKey
        )
        XCTAssertNoThrow(try minPeriod.validate())

        // Test maximum valid period
        let maxPeriod = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            period: 300,
            secretKey: testSecretKey
        )
        XCTAssertNoThrow(try maxPeriod.validate())

        // Test minimum valid counter
        let minCounter = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            counter: 0,
            secretKey: testSecretKey
        )
        XCTAssertNoThrow(try minCounter.validate())
    }

    func testMutableProperties() {
        var credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            secretKey: testSecretKey
        )

        // Test mutable properties can be changed
        credential.displayIssuer = "New Display Issuer"
        credential.displayAccountName = "New Display Account"
        credential.counter = 10
        credential.lockingPolicy = "NewPolicy"
        credential.isLocked = true

        XCTAssertEqual(credential.displayIssuer, "New Display Issuer")
        XCTAssertEqual(credential.displayAccountName, "New Display Account")
        XCTAssertEqual(credential.counter, 10)
        XCTAssertEqual(credential.lockingPolicy, "NewPolicy")
        XCTAssertTrue(credential.isLocked)

        // Original values should remain unchanged
        XCTAssertEqual(credential.issuer, testIssuer)
        XCTAssertEqual(credential.accountName, testAccountName)
    }

    func testIdentifiableConformance() {
        let credential1 = OathCredential(
            id: "id1",
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        let credential2 = OathCredential(
            id: "id2",
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        XCTAssertEqual(credential1.id, "id1")
        XCTAssertEqual(credential2.id, "id2")
        XCTAssertNotEqual(credential1.id, credential2.id)
    }

    func testUniqueIdGeneration() {
        let credential1 = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        let credential2 = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecretKey
        )

        // IDs should be unique when auto-generated
        XCTAssertNotEqual(credential1.id, credential2.id)
        XCTAssertFalse(credential1.id.isEmpty)
        XCTAssertFalse(credential2.id.isEmpty)
    }
}
