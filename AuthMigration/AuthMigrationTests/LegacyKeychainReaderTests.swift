//
//  LegacyKeychainReaderTests.swift
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

final class LegacyKeychainReaderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestKeychainHelper.cleanupLegacyKeychain()
    }

    override func tearDown() {
        super.tearDown()
        TestKeychainHelper.cleanupLegacyKeychain()
    }

    // MARK: - legacyDataExists

    func testLegacyDataExists_returnsFalseWhenEmpty() {
        let reader = LegacyKeychainReader()
        XCTAssertFalse(reader.legacyDataExists())
    }

    func testLegacyDataExists_returnsTrueWhenAccountsExist() throws {
        try TestKeychainHelper.writeLegacyAccount()
        let reader = LegacyKeychainReader()
        XCTAssertTrue(reader.legacyDataExists())
    }

    func testLegacyDataExists_returnsTrueWhenMechanismsExist() throws {
        try TestKeychainHelper.writeLegacyTOTPMechanism()
        let reader = LegacyKeychainReader()
        XCTAssertTrue(reader.legacyDataExists())
    }

    // MARK: - getAllAccounts

    func testGetAllAccounts_returnsEmptyWhenNoData() throws {
        let reader = LegacyKeychainReader()
        let accounts = try reader.getAllAccounts()
        XCTAssertTrue(accounts.isEmpty)
    }

    func testGetAllAccounts_handlesMultipleEntries() throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Issuer1", accountName: "user1")
        try TestKeychainHelper.writeLegacyAccount(issuer: "Issuer2", accountName: "user2")
        try TestKeychainHelper.writeLegacyAccount(issuer: "Issuer3", accountName: "user3")

        let reader = LegacyKeychainReader()
        let accounts = try reader.getAllAccounts()
        XCTAssertEqual(accounts.count, 3)
    }

    func testGetAllAccounts_deserializesCorrectly() throws {
        try TestKeychainHelper.writeLegacyAccount(
            issuer: "MyIssuer", accountName: "myuser@example.com",
            displayIssuer: "My Issuer Corp", displayAccountName: "My User",
            timeAdded: 1_234_567
        )

        let reader = LegacyKeychainReader()
        let accounts = try reader.getAllAccounts()
        XCTAssertEqual(accounts.count, 1)
        let account = accounts[0]
        XCTAssertEqual(account.issuer, "MyIssuer")
        XCTAssertEqual(account.accountName, "myuser@example.com")
        XCTAssertEqual(account.displayIssuer, "My Issuer Corp")
        XCTAssertEqual(account.displayAccountName, "My User")
        XCTAssertEqual(account.timeAdded.timeIntervalSince1970, 1_234_567, accuracy: 0.001)
    }

    // MARK: - getAllMechanisms

    func testGetAllMechanisms_returnsEmptyWhenNoData() throws {
        let reader = LegacyKeychainReader()
        let mechanisms = try reader.getAllMechanisms()
        XCTAssertTrue(mechanisms.isEmpty)
    }

    func testGetAllMechanisms_deserializesTOTPCorrectly() throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyTOTPMechanism(
            mechanismUUID: uuid, issuer: "Org", accountName: "alice",
            algorithm: "sha256", digits: 6, period: 30
        )

        let reader = LegacyKeychainReader()
        let mechanisms = try reader.getAllMechanisms()
        XCTAssertEqual(mechanisms.count, 1)
        XCTAssertEqual(mechanisms[0].type, "totp")
        XCTAssertEqual(mechanisms[0].mechanismUUID, uuid)
        XCTAssertEqual(mechanisms[0].issuer, "Org")
        XCTAssertEqual(mechanisms[0].algorithm, "sha256")
    }

    func testGetAllMechanisms_deserializesHOTPCorrectly() throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyHOTPMechanism(
            mechanismUUID: uuid, counter: 7
        )

        let reader = LegacyKeychainReader()
        let mechanisms = try reader.getAllMechanisms()
        XCTAssertEqual(mechanisms.count, 1)
        XCTAssertEqual(mechanisms[0].type, "hotp")
        XCTAssertEqual(mechanisms[0].counter, 7)
    }

    func testGetAllMechanisms_deserializesPushCorrectly() throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyPushMechanism(
            mechanismUUID: uuid,
            authEndpoint: "https://am.example.com/push?_action=authenticate"
        )

        let reader = LegacyKeychainReader()
        let mechanisms = try reader.getAllMechanisms()
        XCTAssertEqual(mechanisms.count, 1)
        XCTAssertEqual(mechanisms[0].type, "push")
        XCTAssertEqual(mechanisms[0].authEndpoint, "https://am.example.com/push?_action=authenticate")
    }

    func testGetAllMechanisms_handlesMultipleMixedTypes() throws {
        try TestKeychainHelper.writeLegacyTOTPMechanism(mechanismUUID: UUID().uuidString, accountName: "user1")
        try TestKeychainHelper.writeLegacyHOTPMechanism(mechanismUUID: UUID().uuidString, accountName: "user2")
        try TestKeychainHelper.writeLegacyPushMechanism(mechanismUUID: UUID().uuidString, accountName: "user3")

        let reader = LegacyKeychainReader()
        let mechanisms = try reader.getAllMechanisms()
        XCTAssertEqual(mechanisms.count, 3)

        let types = Set(mechanisms.map { $0.type })
        XCTAssertTrue(types.contains("totp"))
        XCTAssertTrue(types.contains("hotp"))
        XCTAssertTrue(types.contains("push"))
    }

    // MARK: - deleteLegacyData

    func testDeleteLegacyData_removesAllServices() throws {
        try TestKeychainHelper.writeLegacyAccount()
        try TestKeychainHelper.writeLegacyTOTPMechanism()

        let reader = LegacyKeychainReader()
        XCTAssertTrue(reader.legacyDataExists())

        reader.deleteLegacyData()

        XCTAssertFalse(reader.legacyDataExists())
    }

    func testDeleteLegacyData_handlesEmptyServicesGracefully() {
        let reader = LegacyKeychainReader()
        // Should not crash on empty Keychain
        reader.deleteLegacyData()
        XCTAssertFalse(reader.legacyDataExists())
    }
}
