//
//  LegacyDataConverterTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath
@testable import PingPush
@testable import PingAuthMigration

final class LegacyDataConverterTests: XCTestCase {

    // MARK: - OATH Tests

    func testToOathCredential_TOTP_mapsAllFields() {
        let account = LegacyAccountArchive(
            issuer: "Acme", accountName: "alice@example.com",
            displayIssuer: "Acme Corp", displayAccountName: "Alice",
            imageUrl: "https://example.com/logo.png", backgroundColor: "#FF0000",
            timeAdded: Date(timeIntervalSince1970: 1_000_000),
            policies: #"{"biometric":true}"#, lockingPolicy: "biometricOnly", lock: true
        )
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid-1", type: "totp",
            secret: "JBSWY3DPEHPK3PXP", issuer: "Acme", accountName: "alice@example.com",
            algorithm: "sha256", digits: 8, period: 60
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)

        XCTAssertEqual(credential.id, "uuid-1")
        XCTAssertEqual(credential.issuer, "Acme")
        XCTAssertEqual(credential.displayIssuer, "Acme Corp")
        XCTAssertEqual(credential.accountName, "alice@example.com")
        XCTAssertEqual(credential.displayAccountName, "Alice")
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.oathAlgorithm, .sha256)
        XCTAssertEqual(credential.digits, 8)
        XCTAssertEqual(credential.period, 60)
        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(credential.backgroundColor, "#FF0000")
        XCTAssertEqual(credential.policies, #"{"biometric":true}"#)
        XCTAssertEqual(credential.lockingPolicy, "biometricOnly")
        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
    }

    func testToOathCredential_HOTP_mapsCounterAndType() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid-hotp", type: "hotp",
            secret: "SECRET", issuer: "Org", accountName: "bob",
            counter: 5
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)

        XCTAssertEqual(credential.oathType, .hotp)
        XCTAssertEqual(credential.counter, 5)
        XCTAssertEqual(credential.period, 0) // HOTP uses 0 period
    }

    func testToOathCredential_defaultDigits() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S",
            issuer: "Org", accountName: "bob", digits: 0
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.digits, 6)
    }

    func testToOathCredential_defaultPeriod() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S",
            issuer: "Org", accountName: "bob", period: 0
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.period, 30)
    }

    func testToOathCredential_defaultAlgorithm() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S",
            issuer: "Org", accountName: "bob", algorithm: nil
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
    }

    func testToOathCredential_prefersAccountTimeAdded() {
        let accountDate = Date(timeIntervalSince1970: 1000)
        let mechanismDate = Date(timeIntervalSince1970: 2000)
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob", timeAdded: accountDate)
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S",
            issuer: "Org", accountName: "bob", timeAdded: mechanismDate
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.createdAt.timeIntervalSince1970, 1000, accuracy: 0.001)
    }

    func testToOathCredential_fallsBackToMechanismTimeAdded() {
        let mechanismDate = Date(timeIntervalSince1970: 2000)
        let account = LegacyAccountArchive(
            issuer: "Org", accountName: "bob",
            timeAdded: Date(timeIntervalSince1970: 0)
        )
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S",
            issuer: "Org", accountName: "bob", timeAdded: mechanismDate
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.createdAt.timeIntervalSince1970, 2000, accuracy: 0.001)
    }

    func testToOathCredential_preservesDisplayNames() {
        let account = LegacyAccountArchive(
            issuer: "Org", accountName: "bob",
            displayIssuer: "Organization", displayAccountName: "Robert"
        )
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S", issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.displayIssuer, "Organization")
        XCTAssertEqual(credential.displayAccountName, "Robert")
    }

    func testToOathCredential_fallsBackDisplayNamesToOriginal() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S", issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.displayIssuer, "Org")
        XCTAssertEqual(credential.displayAccountName, "bob")
    }

    func testToOathCredential_preservesPolicies() {
        let account = LegacyAccountArchive(
            issuer: "Org", accountName: "bob",
            policies: #"{"key":"value"}"#, lockingPolicy: "policy1", lock: true
        )
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "totp", secret: "S", issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toOathCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.policies, #"{"key":"value"}"#)
        XCTAssertEqual(credential.lockingPolicy, "policy1")
        XCTAssertTrue(credential.isLocked)
    }

    // MARK: - Push Tests

    func testToPushCredential_mapsAllFields() {
        // Use a realistic base64url secret (as stored by the legacy iOS SDK)
        let base64UrlSecret = "b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        let expectedBase64Secret = "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E="

        let account = LegacyAccountArchive(
            issuer: "MyCompany", accountName: "user@example.com",
            displayIssuer: "My Company", displayAccountName: "User",
            imageUrl: "https://example.com/img.png",
            backgroundColor: "#0000FF",
            timeAdded: Date(timeIntervalSince1970: 500_000)
        )
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "push-uuid-1", type: "push",
            secret: base64UrlSecret, issuer: "MyCompany", accountName: "user@example.com",
            uid: "user-uid", resourceId: "device-id",
            authEndpoint: "https://am.example.com/json/push?_action=authenticate"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)

        XCTAssertEqual(credential.id, "push-uuid-1")
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.displayIssuer, "My Company")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.displayAccountName, "User")
        XCTAssertEqual(credential.serverEndpoint, "https://am.example.com/json/push")
        XCTAssertEqual(credential.sharedSecret, expectedBase64Secret)
        XCTAssertEqual(credential.userId, "user-uid")
        XCTAssertEqual(credential.resourceId, "device-id")
        XCTAssertEqual(credential.imageURL, "https://example.com/img.png")
        XCTAssertEqual(credential.backgroundColor, "#0000FF")
        XCTAssertEqual(credential.platform, .pingAM)
    }

    func testToPushCredential_stripsQueryParamsFromEndpoint() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "push", secret: "dGVzdA", issuer: "Org", accountName: "bob",
            authEndpoint: "https://host/path?_action=authenticate"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.serverEndpoint, "https://host/path")
    }

    func testToPushCredential_handlesEndpointWithoutQueryParams() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "push", secret: "dGVzdA", issuer: "Org", accountName: "bob",
            authEndpoint: "https://host/path"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.serverEndpoint, "https://host/path")
    }

    func testToPushCredential_defaultPlatform() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "push", secret: "dGVzdA", issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.platform, .pingAM)
    }

    func testToPushCredential_usesResourceIdOrFallsBackToId() {
        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "mechanism-uuid", type: "push", secret: "dGVzdA",
            issuer: "Org", accountName: "bob", resourceId: nil
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.resourceId, "mechanism-uuid")
    }

    // MARK: - Push Secret Base64 Conversion Tests

    func testToPushCredential_recodesBase64UrlSecretToStandardBase64() {
        // base64url: uses '-' and '_', no padding
        let base64UrlSecret = "b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        // standard base64: uses '+' and '/', with '=' padding
        let expectedBase64 = "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E="

        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "push", secret: base64UrlSecret,
            issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)
        XCTAssertEqual(credential.sharedSecret, expectedBase64)

        // Verify the result is valid standard base64
        XCTAssertNotNil(Data(base64Encoded: credential.sharedSecret),
                        "Converted secret must be valid standard base64")
    }

    func testToPushCredential_handlesAlreadyStandardBase64Secret() {
        // A secret that is already in standard base64 should not be corrupted
        let standardBase64Secret = "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E="

        let account = LegacyAccountArchive(issuer: "Org", accountName: "bob")
        let mechanism = LegacyMechanismArchive(
            mechanismUUID: "uuid", type: "push", secret: standardBase64Secret,
            issuer: "Org", accountName: "bob"
        )

        let credential = LegacyDataConverter.toPushCredential(mechanism: mechanism, account: account)

        // The raw bytes should be identical regardless of input format
        let expectedData = Data(base64Encoded: standardBase64Secret)
        let actualData = Data(base64Encoded: credential.sharedSecret)
        XCTAssertEqual(actualData, expectedData,
                       "Standard base64 secret should decode to the same bytes")
    }
}
