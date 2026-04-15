//
//  LegacyArchiveModels.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Lightweight `NSCoding` stand-in for the legacy `FRAuthenticator.Account` class.
///
/// Used during `NSKeyedUnarchiver` deserialization with class name mapping to extract
/// archived account fields without depending on the legacy `FRAuthenticator` module.
///
/// ## NSCoding Keys
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"issuer"` | `NSString` | Required |
/// | `"accountName"` | `NSString` | Required |
/// | `"displayIssuer"` | `NSString` | Optional |
/// | `"displayAccountName"` | `NSString` | Optional |
/// | `"imageUrl"` | `NSString` | Optional |
/// | `"backgroundColor"` | `NSString` | Optional hex color |
/// | `"timeAdded"` | `Double` | Seconds since 1970 |
/// | `"policies"` | `NSString` | Optional JSON string |
/// | `"lockingPolicy"` | `NSString` | Optional |
/// | `"lock"` | `Bool` | Lock state |
///
/// - SeeAlso: ``LegacyMechanismArchive``
/// - SeeAlso: ``LegacyKeychainReader``
internal class LegacyAccountArchive: NSObject, NSCoding {
    let issuer: String
    let accountName: String
    let displayIssuer: String?
    let displayAccountName: String?
    let imageUrl: String?
    let backgroundColor: String?
    let timeAdded: Date
    let policies: String?
    let lockingPolicy: String?
    let lock: Bool

    required init?(coder: NSCoder) {
        self.issuer = coder.decodeObject(forKey: "issuer") as? String ?? ""
        self.accountName = coder.decodeObject(forKey: "accountName") as? String ?? ""
        self.displayIssuer = coder.decodeObject(forKey: "displayIssuer") as? String
        self.displayAccountName = coder.decodeObject(forKey: "displayAccountName") as? String
        self.imageUrl = coder.decodeObject(forKey: "imageUrl") as? String
        self.backgroundColor = coder.decodeObject(forKey: "backgroundColor") as? String
        self.timeAdded = Date(timeIntervalSince1970: coder.decodeDouble(forKey: "timeAdded"))
        self.policies = coder.decodeObject(forKey: "policies") as? String
        self.lockingPolicy = coder.decodeObject(forKey: "lockingPolicy") as? String
        self.lock = coder.decodeBool(forKey: "lock")
        super.init()
    }

    func encode(with coder: NSCoder) {
        // Encoding is not needed for migration — this class is read-only.
    }

    // MARK: - Internal test initializer

    /// Convenience initializer for unit testing without NSKeyedArchiver.
    internal init(
        issuer: String,
        accountName: String,
        displayIssuer: String? = nil,
        displayAccountName: String? = nil,
        imageUrl: String? = nil,
        backgroundColor: String? = nil,
        timeAdded: Date = Date(),
        policies: String? = nil,
        lockingPolicy: String? = nil,
        lock: Bool = false
    ) {
        self.issuer = issuer
        self.accountName = accountName
        self.displayIssuer = displayIssuer
        self.displayAccountName = displayAccountName
        self.imageUrl = imageUrl
        self.backgroundColor = backgroundColor
        self.timeAdded = timeAdded
        self.policies = policies
        self.lockingPolicy = lockingPolicy
        self.lock = lock
        super.init()
    }
}

/// Lightweight `NSCoding` stand-in for the legacy mechanism classes:
/// `FRAuthenticator.TOTPMechanism`, `FRAuthenticator.HOTPMechanism`, and
/// `FRAuthenticator.PushMechanism`.
///
/// A single class handles all three mechanism types. The `type` field distinguishes
/// between `"totp"`, `"hotp"`, and `"push"`. OATH-specific fields (`algorithm`, `digits`,
/// `period`, `counter`) and Push-specific fields (`authEndpoint`, `regEndpoint`) are all
/// decoded but may be `nil` depending on `type`.
///
/// ## NSCoding Keys (base Mechanism)
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"mechanismUUID"` | `NSString` | UUID |
/// | `"type"` | `NSString` | `"totp"`, `"hotp"`, or `"push"` |
/// | `"version"` | `Int` | Internal version, not migrated |
/// | `"secret"` | `NSString` | Shared secret |
/// | `"issuer"` | `NSString` | |
/// | `"accountName"` | `NSString` | |
/// | `"uid"` | `NSString` | Optional user ID |
/// | `"resourceId"` | `NSString` | Optional server-side ID |
/// | `"timeAdded"` | `Double` | Seconds since 1970 |
///
/// ## NSCoding Keys (OathMechanism extensions)
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"algorithm"` | `NSString` | `"sha1"`, `"sha256"`, `"sha512"` |
/// | `"digits"` | `Int` | Default 6 |
///
/// ## NSCoding Keys (TOTPMechanism extension)
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"period"` | `Int` | Default 30 |
///
/// ## NSCoding Keys (HOTPMechanism extension)
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"counter"` | `Int` | Default 0 |
///
/// ## NSCoding Keys (PushMechanism extensions)
///
/// | Key | Type | Notes |
/// |-----|------|-------|
/// | `"authEndpoint"` | `NSString` | URL as string |
/// | `"regEndpoint"` | `NSString` | URL as string |
/// | `"messageId"` | `NSString` | Registration-time only |
/// | `"challenge"` | `NSString` | Registration-time only |
/// | `"loadBalancer"` | `NSString` | Optional |
///
/// - SeeAlso: ``LegacyAccountArchive``
/// - SeeAlso: ``LegacyKeychainReader``
internal class LegacyMechanismArchive: NSObject, NSCoding {

    // Base Mechanism fields
    let mechanismUUID: String
    let type: String
    let secret: String
    let issuer: String
    let accountName: String
    let uid: String?
    let resourceId: String?
    let timeAdded: Date

    // OathMechanism fields (nil for Push)
    let algorithm: String?
    let digits: Int
    let period: Int
    let counter: Int

    // PushMechanism fields (nil for OATH)
    let authEndpoint: String?
    let regEndpoint: String?

    required init?(coder: NSCoder) {
        self.mechanismUUID = coder.decodeObject(forKey: "mechanismUUID") as? String ?? ""
        self.type = coder.decodeObject(forKey: "type") as? String ?? ""
        self.secret = coder.decodeObject(forKey: "secret") as? String ?? ""
        self.issuer = coder.decodeObject(forKey: "issuer") as? String ?? ""
        self.accountName = coder.decodeObject(forKey: "accountName") as? String ?? ""
        self.uid = coder.decodeObject(forKey: "uid") as? String
        self.resourceId = coder.decodeObject(forKey: "resourceId") as? String
        self.timeAdded = Date(timeIntervalSince1970: coder.decodeDouble(forKey: "timeAdded"))

        // OATH fields
        self.algorithm = coder.decodeObject(forKey: "algorithm") as? String
        self.digits = coder.decodeInteger(forKey: "digits")
        self.period = coder.decodeInteger(forKey: "period")
        self.counter = coder.decodeInteger(forKey: "counter")

        // Push fields
        self.authEndpoint = coder.decodeObject(forKey: "authEndpoint") as? String
        self.regEndpoint = coder.decodeObject(forKey: "regEndpoint") as? String

        super.init()
    }

    func encode(with coder: NSCoder) {
        // Encoding is not needed for migration — this class is read-only.
    }

    // MARK: - Internal test initializer

    /// Convenience initializer for unit testing without NSKeyedArchiver.
    internal init(
        mechanismUUID: String,
        type: String,
        secret: String,
        issuer: String,
        accountName: String,
        uid: String? = nil,
        resourceId: String? = nil,
        timeAdded: Date = Date(),
        algorithm: String? = nil,
        digits: Int = 6,
        period: Int = 30,
        counter: Int = 0,
        authEndpoint: String? = nil,
        regEndpoint: String? = nil
    ) {
        self.mechanismUUID = mechanismUUID
        self.type = type
        self.secret = secret
        self.issuer = issuer
        self.accountName = accountName
        self.uid = uid
        self.resourceId = resourceId
        self.timeAdded = timeAdded
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.authEndpoint = authEndpoint
        self.regEndpoint = regEndpoint
        super.init()
    }
}
