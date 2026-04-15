//
//  TestKeychainHelper.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
@testable import PingAuthMigration

/// Utility for writing and cleaning up legacy FRAuthenticator-formatted Keychain entries
/// used in unit tests for `LegacyKeychainReader`.
struct TestKeychainHelper {

    // MARK: - Write helpers

    /// Writes a legacy-format account archive to the legacy account Keychain service.
    static func writeLegacyAccount(
        issuer: String = "TestIssuer",
        accountName: String = "user@example.com",
        displayIssuer: String? = nil,
        displayAccountName: String? = nil,
        imageUrl: String? = nil,
        backgroundColor: String? = nil,
        timeAdded: Double = 1_000_000,
        policies: String? = nil,
        lockingPolicy: String? = nil,
        lock: Bool = false,
        accessGroup: String? = nil
    ) throws {
        let data = archiveAccount(
            issuer: issuer, accountName: accountName,
            displayIssuer: displayIssuer, displayAccountName: displayAccountName,
            imageUrl: imageUrl, backgroundColor: backgroundColor,
            timeAdded: timeAdded, policies: policies, lockingPolicy: lockingPolicy, lock: lock
        )
        try writeItem(data: data, service: LegacyKeychainReader.accountService,
                      account: "\(issuer)-\(accountName)", accessGroup: accessGroup)
    }

    /// Writes a legacy-format TOTP mechanism archive to the legacy mechanism Keychain service.
    static func writeLegacyTOTPMechanism(
        mechanismUUID: String = UUID().uuidString,
        issuer: String = "TestIssuer",
        accountName: String = "user@example.com",
        secret: String = "JBSWY3DPEHPK3PXP",
        algorithm: String = "sha1",
        digits: Int = 6,
        period: Int = 30,
        timeAdded: Double = 1_000_000,
        accessGroup: String? = nil
    ) throws {
        let data = archiveMechanism(
            legacyClassName: "FRAuthenticator.TOTPMechanism", mechanismUUID: mechanismUUID,
            type: "totp", secret: secret, issuer: issuer, accountName: accountName,
            timeAdded: timeAdded, algorithm: algorithm, digits: digits, period: period
        )
        try writeItem(data: data, service: LegacyKeychainReader.mechanismService,
                      account: mechanismUUID, accessGroup: accessGroup)
    }

    /// Writes a legacy-format HOTP mechanism archive to the legacy mechanism Keychain service.
    static func writeLegacyHOTPMechanism(
        mechanismUUID: String = UUID().uuidString,
        issuer: String = "TestIssuer",
        accountName: String = "user@example.com",
        secret: String = "JBSWY3DPEHPK3PXP",
        counter: Int = 0,
        timeAdded: Double = 1_000_000,
        accessGroup: String? = nil
    ) throws {
        let data = archiveMechanism(
            legacyClassName: "FRAuthenticator.HOTPMechanism", mechanismUUID: mechanismUUID,
            type: "hotp", secret: secret, issuer: issuer, accountName: accountName,
            timeAdded: timeAdded, counter: counter
        )
        try writeItem(data: data, service: LegacyKeychainReader.mechanismService,
                      account: mechanismUUID, accessGroup: accessGroup)
    }

    /// Writes a legacy-format Push mechanism archive to the legacy mechanism Keychain service.
    static func writeLegacyPushMechanism(
        mechanismUUID: String = UUID().uuidString,
        issuer: String = "TestIssuer",
        accountName: String = "user@example.com",
        secret: String = "PUSHSECRET",
        authEndpoint: String = "https://am.example.com/push?_action=authenticate",
        timeAdded: Double = 1_000_000,
        accessGroup: String? = nil
    ) throws {
        let data = archiveMechanism(
            legacyClassName: "FRAuthenticator.PushMechanism", mechanismUUID: mechanismUUID,
            type: "push", secret: secret, issuer: issuer, accountName: accountName,
            timeAdded: timeAdded, authEndpoint: authEndpoint
        )
        try writeItem(data: data, service: LegacyKeychainReader.mechanismService,
                      account: mechanismUUID, accessGroup: accessGroup)
    }

    // MARK: - Cleanup

    /// Deletes all entries from all four legacy Keychain services.
    static func cleanupLegacyKeychain(accessGroup: String? = nil) {
        let services = [
            LegacyKeychainReader.accountService,
            LegacyKeychainReader.mechanismService,
            LegacyKeychainReader.notificationService,
            LegacyKeychainReader.deviceTokenService
        ]
        for service in services {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            if let group = accessGroup {
                query[kSecAttrAccessGroup as String] = group
            }
            SecItemDelete(query as CFDictionary)
        }
    }

    // MARK: - Private helpers

    private static func writeItem(data: Data, service: String, account: String, accessGroup: String?) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        // Delete first to avoid duplicate errors
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func archiveAccount(
        issuer: String, accountName: String,
        displayIssuer: String?, displayAccountName: String?,
        imageUrl: String?, backgroundColor: String?,
        timeAdded: Double, policies: String?,
        lockingPolicy: String?, lock: Bool
    ) -> Data {
        let coder = TestAccountCoder(
            issuer: issuer, accountName: accountName,
            displayIssuer: displayIssuer, displayAccountName: displayAccountName,
            imageUrl: imageUrl, backgroundColor: backgroundColor,
            timeAdded: timeAdded, policies: policies,
            lockingPolicy: lockingPolicy, lock: lock
        )
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName("FRAuthenticator.Account", for: TestAccountCoder.self)
        archiver.encode(coder, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private static func archiveMechanism(
        legacyClassName: String,
        mechanismUUID: String, type: String, secret: String,
        issuer: String, accountName: String,
        timeAdded: Double,
        algorithm: String? = nil,
        digits: Int = 0, period: Int = 0, counter: Int = 0,
        authEndpoint: String? = nil, regEndpoint: String? = nil
    ) -> Data {
        let coder = TestMechanismCoder(
            mechanismUUID: mechanismUUID, type: type, secret: secret,
            issuer: issuer, accountName: accountName, timeAdded: timeAdded,
            algorithm: algorithm, digits: digits, period: period, counter: counter,
            authEndpoint: authEndpoint, regEndpoint: regEndpoint
        )
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName(legacyClassName, for: TestMechanismCoder.self)
        archiver.encode(coder, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }
}

// MARK: - NSCoding helpers (package-private to test target)

class TestAccountCoder: NSObject, NSCoding {
    let issuer: String; let accountName: String
    let displayIssuer: String?; let displayAccountName: String?
    let imageUrl: String?; let backgroundColor: String?
    let timeAdded: Double; let policies: String?
    let lockingPolicy: String?; let lock: Bool

    init(issuer: String, accountName: String, displayIssuer: String?, displayAccountName: String?,
         imageUrl: String? = nil, backgroundColor: String? = nil,
         timeAdded: Double, policies: String?, lockingPolicy: String?, lock: Bool) {
        self.issuer = issuer; self.accountName = accountName
        self.displayIssuer = displayIssuer; self.displayAccountName = displayAccountName
        self.imageUrl = imageUrl; self.backgroundColor = backgroundColor
        self.timeAdded = timeAdded; self.policies = policies
        self.lockingPolicy = lockingPolicy; self.lock = lock
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

class TestMechanismCoder: NSObject, NSCoding {
    let mechanismUUID: String; let type: String; let secret: String
    let issuer: String; let accountName: String; let timeAdded: Double
    let algorithm: String?; let digits: Int; let period: Int; let counter: Int
    let authEndpoint: String?; let regEndpoint: String?

    init(mechanismUUID: String, type: String, secret: String, issuer: String, accountName: String,
         timeAdded: Double, algorithm: String?, digits: Int, period: Int, counter: Int,
         authEndpoint: String?, regEndpoint: String?) {
        self.mechanismUUID = mechanismUUID; self.type = type; self.secret = secret
        self.issuer = issuer; self.accountName = accountName; self.timeAdded = timeAdded
        self.algorithm = algorithm; self.digits = digits; self.period = period; self.counter = counter
        self.authEndpoint = authEndpoint; self.regEndpoint = regEndpoint
    }

    required init?(coder: NSCoder) { return nil }

    func encode(with coder: NSCoder) {
        coder.encode(mechanismUUID, forKey: "mechanismUUID")
        coder.encode(type, forKey: "type")
        coder.encode(secret, forKey: "secret")
        coder.encode(issuer, forKey: "issuer")
        coder.encode(accountName, forKey: "accountName")
        coder.encode(timeAdded, forKey: "timeAdded")
        if let v = algorithm { coder.encode(v, forKey: "algorithm") }
        coder.encode(digits, forKey: "digits")
        coder.encode(period, forKey: "period")
        coder.encode(counter, forKey: "counter")
        if let v = authEndpoint { coder.encode(v, forKey: "authEndpoint") }
        if let v = regEndpoint { coder.encode(v, forKey: "regEndpoint") }
    }
}
