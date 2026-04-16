//
//  LegacyArchiveModelsTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingAuthMigration

// MARK: - NSCoding helpers for creating test archives

/// Creates an NSKeyedArchiver archive encoding Account-shaped data.
private func makeAccountData(
    issuer: String = "TestIssuer",
    accountName: String = "user@example.com",
    displayIssuer: String? = nil,
    displayAccountName: String? = nil,
    imageUrl: String? = nil,
    backgroundColor: String? = nil,
    timeAdded: Double = 1_000_000,
    policies: String? = nil,
    lockingPolicy: String? = nil,
    lock: Bool = false
) -> Data {
    let archiver = NSKeyedArchiver(requiringSecureCoding: false)
    archiver.encode(issuer, forKey: "issuer")
    archiver.encode(accountName, forKey: "accountName")
    if let v = displayIssuer { archiver.encode(v, forKey: "displayIssuer") }
    if let v = displayAccountName { archiver.encode(v, forKey: "displayAccountName") }
    if let v = imageUrl { archiver.encode(v, forKey: "imageUrl") }
    if let v = backgroundColor { archiver.encode(v, forKey: "backgroundColor") }
    archiver.encode(timeAdded, forKey: "timeAdded")
    if let v = policies { archiver.encode(v, forKey: "policies") }
    if let v = lockingPolicy { archiver.encode(v, forKey: "lockingPolicy") }
    archiver.encode(lock, forKey: "lock")
    archiver.finishEncoding()
    return archiver.encodedData
}

// MARK: - Tests

final class LegacyArchiveModelsTests: XCTestCase {

    func testAccountArchive_decodesAllFields() {
        let data = makeAccountArchiveData(
            issuer: "Acme",
            accountName: "alice@example.com",
            displayIssuer: "Acme Corp",
            displayAccountName: "Alice",
            imageUrl: "https://example.com/logo.png",
            backgroundColor: "#FF0000",
            timeAdded: 1_234_567,
            policies: #"{"biometric":true}"#,
            lockingPolicy: "biometricOnly",
            lock: true
        )

        let account = unarchiveLegacyAccount(from: data)
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.issuer, "Acme")
        XCTAssertEqual(account?.accountName, "alice@example.com")
        XCTAssertEqual(account?.displayIssuer, "Acme Corp")
        XCTAssertEqual(account?.displayAccountName, "Alice")
        XCTAssertEqual(account?.imageUrl, "https://example.com/logo.png")
        XCTAssertEqual(account?.backgroundColor, "#FF0000")
        XCTAssertEqual(account?.timeAdded.timeIntervalSince1970 ?? 0, 1_234_567, accuracy: 0.001)
        XCTAssertEqual(account?.policies, #"{"biometric":true}"#)
        XCTAssertEqual(account?.lockingPolicy, "biometricOnly")
        XCTAssertEqual(account?.lock, true)
    }

    func testAccountArchive_handlesOptionalFields() {
        let data = makeAccountArchiveData(issuer: "Org", accountName: "bob", timeAdded: 500)
        let account = unarchiveLegacyAccount(from: data)
        XCTAssertNotNil(account)
        XCTAssertNil(account?.displayIssuer)
        XCTAssertNil(account?.displayAccountName)
        XCTAssertNil(account?.imageUrl)
        XCTAssertNil(account?.backgroundColor)
        XCTAssertNil(account?.policies)
        XCTAssertNil(account?.lockingPolicy)
        XCTAssertFalse(account?.lock ?? true)
    }

    func testMechanismArchive_decodesTOTPFields() {
        let data = makeMechanismArchiveData(
            type: "totp",
            algorithm: "sha256",
            digits: 8,
            period: 60
        )
        let mechanism = unarchiveLegacyMechanism(from: data)
        XCTAssertNotNil(mechanism)
        XCTAssertEqual(mechanism?.type, "totp")
        XCTAssertEqual(mechanism?.algorithm, "sha256")
        XCTAssertEqual(mechanism?.digits, 8)
        XCTAssertEqual(mechanism?.period, 60)
    }

    func testMechanismArchive_decodesHOTPFields() {
        let data = makeMechanismArchiveData(type: "hotp", counter: 42)
        let mechanism = unarchiveLegacyMechanism(from: data)
        XCTAssertNotNil(mechanism)
        XCTAssertEqual(mechanism?.type, "hotp")
        XCTAssertEqual(mechanism?.counter, 42)
    }

    func testMechanismArchive_decodesPushFields() {
        let data = makeMechanismArchiveData(
            type: "push",
            authEndpoint: "https://am.example.com/push?_action=authenticate",
            regEndpoint: "https://am.example.com/push?_action=register"
        )
        let mechanism = unarchiveLegacyMechanism(from: data)
        XCTAssertNotNil(mechanism)
        XCTAssertEqual(mechanism?.type, "push")
        XCTAssertEqual(mechanism?.authEndpoint, "https://am.example.com/push?_action=authenticate")
        XCTAssertEqual(mechanism?.regEndpoint, "https://am.example.com/push?_action=register")
    }

    func testMechanismArchive_handlesOptionalFields() {
        let data = makeMechanismArchiveData(type: "totp")
        let mechanism = unarchiveLegacyMechanism(from: data)
        XCTAssertNotNil(mechanism)
        XCTAssertNil(mechanism?.uid)
        XCTAssertNil(mechanism?.resourceId)
        XCTAssertNil(mechanism?.authEndpoint)
        XCTAssertNil(mechanism?.regEndpoint)
    }
}

// MARK: - Direct archive helpers (bypass class name proxy complexity)

private func makeAccountArchiveData(
    issuer: String,
    accountName: String,
    displayIssuer: String? = nil,
    displayAccountName: String? = nil,
    imageUrl: String? = nil,
    backgroundColor: String? = nil,
    timeAdded: Double = 0,
    policies: String? = nil,
    lockingPolicy: String? = nil,
    lock: Bool = false
) -> Data {
    // Archive directly as LegacyAccountArchive by encoding keys manually via a helper
    let helper = DirectAccountCoder(
        issuer: issuer, accountName: accountName,
        displayIssuer: displayIssuer, displayAccountName: displayAccountName,
        imageUrl: imageUrl, backgroundColor: backgroundColor,
        timeAdded: timeAdded, policies: policies,
        lockingPolicy: lockingPolicy, lock: lock
    )
    return (try? NSKeyedArchiver.archivedData(withRootObject: helper, requiringSecureCoding: false)) ?? Data()
}

private func makeMechanismArchiveData(
    type: String,
    mechanismUUID: String = "test-uuid",
    secret: String = "TESTSECRET",
    issuer: String = "Issuer",
    accountName: String = "account",
    uid: String? = nil,
    resourceId: String? = nil,
    timeAdded: Double = 1000,
    algorithm: String? = nil,
    digits: Int = 0,
    period: Int = 0,
    counter: Int = 0,
    authEndpoint: String? = nil,
    regEndpoint: String? = nil
) -> Data {
    let helper = DirectMechanismCoder(
        mechanismUUID: mechanismUUID, type: type, secret: secret,
        issuer: issuer, accountName: accountName,
        uid: uid, resourceId: resourceId, timeAdded: timeAdded,
        algorithm: algorithm, digits: digits, period: period, counter: counter,
        authEndpoint: authEndpoint, regEndpoint: regEndpoint
    )
    return (try? NSKeyedArchiver.archivedData(withRootObject: helper, requiringSecureCoding: false)) ?? Data()
}

private func unarchiveLegacyAccount(from data: Data) -> LegacyAccountArchive? {
    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
    unarchiver.requiresSecureCoding = false
    // Map the helper class name to LegacyAccountArchive
    unarchiver.setClass(LegacyAccountArchive.self, forClassName: NSStringFromClass(DirectAccountCoder.self))
    let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyAccountArchive
    unarchiver.finishDecoding()
    return obj
}

private func unarchiveLegacyMechanism(from data: Data) -> LegacyMechanismArchive? {
    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
    unarchiver.requiresSecureCoding = false
    unarchiver.setClass(LegacyMechanismArchive.self, forClassName: NSStringFromClass(DirectMechanismCoder.self))
    let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyMechanismArchive
    unarchiver.finishDecoding()
    return obj
}

// MARK: - Direct coder helpers

@objc(DirectAccountCoder)
private class DirectAccountCoder: NSObject, NSCoding {
    let issuer: String; let accountName: String; let displayIssuer: String?
    let displayAccountName: String?; let imageUrl: String?; let backgroundColor: String?
    let timeAdded: Double; let policies: String?; let lockingPolicy: String?; let lock: Bool

    init(issuer: String, accountName: String, displayIssuer: String?, displayAccountName: String?,
         imageUrl: String?, backgroundColor: String?, timeAdded: Double, policies: String?,
         lockingPolicy: String?, lock: Bool) {
        self.issuer = issuer; self.accountName = accountName; self.displayIssuer = displayIssuer
        self.displayAccountName = displayAccountName; self.imageUrl = imageUrl
        self.backgroundColor = backgroundColor; self.timeAdded = timeAdded
        self.policies = policies; self.lockingPolicy = lockingPolicy; self.lock = lock
    }

    required init?(coder: NSCoder) { return nil }

    func encode(with coder: NSCoder) {
        coder.encode(issuer, forKey: "issuer")
        coder.encode(accountName, forKey: "accountName")
        if let v = displayIssuer { coder.encode(v, forKey: "displayIssuer") }
        if let v = displayAccountName { coder.encode(v, forKey: "displayAccountName") }
        if let v = imageUrl { coder.encode(v, forKey: "imageUrl") }
        if let v = backgroundColor { coder.encode(v, forKey: "backgroundColor") }
        coder.encode(timeAdded, forKey: "timeAdded")
        if let v = policies { coder.encode(v, forKey: "policies") }
        if let v = lockingPolicy { coder.encode(v, forKey: "lockingPolicy") }
        coder.encode(lock, forKey: "lock")
    }
}

@objc(DirectMechanismCoder)
private class DirectMechanismCoder: NSObject, NSCoding {
    let mechanismUUID: String; let type: String; let secret: String
    let issuer: String; let accountName: String; let uid: String?; let resourceId: String?
    let timeAdded: Double; let algorithm: String?
    let digits: Int; let period: Int; let counter: Int
    let authEndpoint: String?; let regEndpoint: String?

    init(mechanismUUID: String, type: String, secret: String, issuer: String, accountName: String,
         uid: String?, resourceId: String?, timeAdded: Double, algorithm: String?,
         digits: Int, period: Int, counter: Int, authEndpoint: String?, regEndpoint: String?) {
        self.mechanismUUID = mechanismUUID; self.type = type; self.secret = secret
        self.issuer = issuer; self.accountName = accountName; self.uid = uid
        self.resourceId = resourceId; self.timeAdded = timeAdded; self.algorithm = algorithm
        self.digits = digits; self.period = period; self.counter = counter
        self.authEndpoint = authEndpoint; self.regEndpoint = regEndpoint
    }

    required init?(coder: NSCoder) { return nil }

    func encode(with coder: NSCoder) {
        coder.encode(mechanismUUID, forKey: "mechanismUUID")
        coder.encode(type, forKey: "type")
        coder.encode(secret, forKey: "secret")
        coder.encode(issuer, forKey: "issuer")
        coder.encode(accountName, forKey: "accountName")
        if let v = uid { coder.encode(v, forKey: "uid") }
        if let v = resourceId { coder.encode(v, forKey: "resourceId") }
        coder.encode(timeAdded, forKey: "timeAdded")
        if let v = algorithm { coder.encode(v, forKey: "algorithm") }
        coder.encode(digits, forKey: "digits")
        coder.encode(period, forKey: "period")
        coder.encode(counter, forKey: "counter")
        if let v = authEndpoint { coder.encode(v, forKey: "authEndpoint") }
        if let v = regEndpoint { coder.encode(v, forKey: "regEndpoint") }
    }
}
