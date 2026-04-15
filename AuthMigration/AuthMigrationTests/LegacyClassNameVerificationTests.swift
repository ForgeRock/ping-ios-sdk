//
//  LegacyClassNameVerificationTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import Foundation
@testable import PingAuthMigration

/// Verifies that the `NSKeyedUnarchiver` class name mapping used in `LegacyKeychainReader`
/// correctly maps `FRAuthenticator.*` class names to the local stand-in types.
///
/// The class names confirmed here must match the names stored in real `FRAuthenticator`
/// archives. If they differ, update the mappings in `LegacyKeychainReader.deserializeAccount`
/// and `LegacyKeychainReader.deserializeMechanism`.
final class LegacyClassNameVerificationTests: XCTestCase {

    // MARK: - Account Class Name

    /// Verifies that an archive created with class name "FRAuthenticator.Account" is
    /// correctly decoded to `LegacyAccountArchive` via the unarchiver's class name mapping.
    func testClassNameMapping_Account() throws {
        // Create an archive whose root object encodes as "FRAuthenticator.Account"
        let data = archiveWithClassName("FRAuthenticator.Account") { coder in
            coder.encode("Acme", forKey: "issuer")
            coder.encode("user@example.com", forKey: "accountName")
            coder.encode(1_000_000.0, forKey: "timeAdded")
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyAccountArchive.self, forClassName: "FRAuthenticator.Account")

        let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()

        XCTAssertNotNil(result as? LegacyAccountArchive,
            "Expected LegacyAccountArchive but got \(String(describing: type(of: result)))")
        guard let account = result as? LegacyAccountArchive else { return }
        XCTAssertEqual(account.issuer, "Acme")
        XCTAssertEqual(account.accountName, "user@example.com")
    }

    // MARK: - Mechanism Class Names

    /// Verifies that an archive created with class name "FRAuthenticator.TOTPMechanism" is
    /// correctly decoded to `LegacyMechanismArchive`.
    func testClassNameMapping_TOTPMechanism() throws {
        let data = archiveWithClassName("FRAuthenticator.TOTPMechanism") { coder in
            coder.encode(UUID().uuidString, forKey: "mechanismUUID")
            coder.encode("totp", forKey: "type")
            coder.encode("JBSWY3DPEHPK3PXP", forKey: "secret")
            coder.encode("Acme", forKey: "issuer")
            coder.encode("user@example.com", forKey: "accountName")
            coder.encode(1_000_000.0, forKey: "timeAdded")
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: "FRAuthenticator.TOTPMechanism")

        let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()

        XCTAssertNotNil(result as? LegacyMechanismArchive,
            "Expected LegacyMechanismArchive but got \(String(describing: type(of: result)))")
        guard let mechanism = result as? LegacyMechanismArchive else { return }
        XCTAssertEqual(mechanism.type, "totp")
    }

    /// Verifies that an archive created with class name "FRAuthenticator.HOTPMechanism" is
    /// correctly decoded to `LegacyMechanismArchive`.
    func testClassNameMapping_HOTPMechanism() throws {
        let data = archiveWithClassName("FRAuthenticator.HOTPMechanism") { coder in
            coder.encode(UUID().uuidString, forKey: "mechanismUUID")
            coder.encode("hotp", forKey: "type")
            coder.encode("HOTPSECRET", forKey: "secret")
            coder.encode("Acme", forKey: "issuer")
            coder.encode("user@example.com", forKey: "accountName")
            coder.encode(1_000_000.0, forKey: "timeAdded")
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: "FRAuthenticator.HOTPMechanism")

        let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()

        XCTAssertNotNil(result as? LegacyMechanismArchive,
            "Expected LegacyMechanismArchive but got \(String(describing: type(of: result)))")
        guard let mechanism = result as? LegacyMechanismArchive else { return }
        XCTAssertEqual(mechanism.type, "hotp")
    }

    /// Verifies that an archive created with class name "FRAuthenticator.PushMechanism" is
    /// correctly decoded to `LegacyMechanismArchive`.
    func testClassNameMapping_PushMechanism() throws {
        let data = archiveWithClassName("FRAuthenticator.PushMechanism") { coder in
            coder.encode(UUID().uuidString, forKey: "mechanismUUID")
            coder.encode("push", forKey: "type")
            coder.encode("PUSHSECRET", forKey: "secret")
            coder.encode("Acme", forKey: "issuer")
            coder.encode("user@example.com", forKey: "accountName")
            coder.encode(1_000_000.0, forKey: "timeAdded")
            coder.encode("https://am.example.com/push?_action=authenticate", forKey: "authEndpoint")
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: "FRAuthenticator.PushMechanism")

        let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()

        XCTAssertNotNil(result as? LegacyMechanismArchive,
            "Expected LegacyMechanismArchive but got \(String(describing: type(of: result)))")
        guard let mechanism = result as? LegacyMechanismArchive else { return }
        XCTAssertEqual(mechanism.type, "push")
    }
}

// MARK: - Private Helpers

private extension LegacyClassNameVerificationTests {

    /// Creates an `NSKeyedArchiver` archive where the root object is encoded under the
    /// specified class name. This simulates how a real `FRAuthenticator` object would
    /// appear in the Keychain.
    ///
    /// - Parameters:
    ///   - className: The ObjC class name to use as the root (e.g. `"FRAuthenticator.Account"`).
    ///   - encode: Closure that encodes fields using the provided `NSCoder`.
    /// - Returns: The archived `Data`.
    func archiveWithClassName(_ className: String, encode: @escaping (NSCoder) -> Void) -> Data {
        let helper = ClassNameArchiveHelper(className: className, encoder: encode)
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName(className, for: ClassNameArchiveHelper.self)
        archiver.encode(helper, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }
}

/// A generic `NSObject` + `NSCoding` helper that encodes fields using a provided closure.
///
/// The class name in the archive is controlled via `NSKeyedArchiver.setClassName(_:for:)`
/// in the calling code, not by overriding `classForCoder`.
@objc(ClassNameArchiveHelper)
private class ClassNameArchiveHelper: NSObject, NSCoding {
    private let _encoder: (NSCoder) -> Void

    init(className: String, encoder: @escaping (NSCoder) -> Void) {
        self._encoder = encoder
    }

    required init?(coder: NSCoder) { return nil }

    func encode(with coder: NSCoder) {
        _encoder(coder)
    }
}
