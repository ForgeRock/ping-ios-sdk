//
//  LegacyKeychainReader.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Security
import PingLogger

/// Reads and deletes legacy `FRAuthenticator` data from the iOS Keychain.
///
/// `LegacyKeychainReader` accesses the four Keychain service namespaces used by the legacy
/// `KeychainServiceClient`:
///
/// | Type | Service Identifier |
/// |------|--------------------|
/// | Account | `com.forgerock.ios.authenticator.keychainservice.local.account` |
/// | Mechanism | `com.forgerock.ios.authenticator.keychainservice.local.mechanism` |
/// | Notification | `com.forgerock.ios.authenticator.keychainservice.local.notification` |
/// | Device Token | `com.forgerock.ios.authenticator.keychainservice.local.pushDeviceToken` |
///
/// If the legacy SDK used Secure Enclave encryption (via `SecuredKey`), data is automatically
/// decrypted using ``LegacySecuredKey`` before `NSKeyedUnarchiver` deserialization.
///
/// ## Class Name Mapping
///
/// Since this module does not depend on `FRAuthenticator`, `NSKeyedUnarchiver` class name
/// mapping is used to redirect legacy class references to local ``LegacyAccountArchive``
/// and ``LegacyMechanismArchive`` stand-in classes.
///
/// - SeeAlso: ``LegacySecuredKey``
/// - SeeAlso: ``LegacyAccountArchive``
/// - SeeAlso: ``LegacyMechanismArchive``
internal class LegacyKeychainReader {

    // MARK: - Constants

    /// Base Keychain service identifier used by legacy `FRAuthenticator`.
    private static let baseService = "com.forgerock.ios.authenticator.keychainservice.local"

    /// Keychain service for legacy accounts.
    static let accountService = "\(baseService).account"

    /// Keychain service for legacy mechanisms.
    static let mechanismService = "\(baseService).mechanism"

    /// Keychain service for legacy push notifications.
    static let notificationService = "\(baseService).notification"

    /// Keychain service for legacy push device tokens.
    static let deviceTokenService = "\(baseService).pushDeviceToken"

    // MARK: - Legacy Class Names (for NSKeyedUnarchiver mapping)

    private static let legacyAccountClass = "FRAuthenticator.Account"
    private static let legacyTOTPClass = "FRAuthenticator.TOTPMechanism"
    private static let legacyHOTPClass = "FRAuthenticator.HOTPMechanism"
    private static let legacyPushClass = "FRAuthenticator.PushMechanism"

    // MARK: - Properties

    /// Optional Keychain access group matching the legacy SDK configuration.
    private let accessGroup: String?

    /// Legacy Secure Enclave key for decrypting encrypted Keychain data.
    /// `nil` if the legacy SDK did not use encryption.
    private let securedKey: LegacySecuredKey?

    /// Logger for diagnostic output.
    private let logger: Logger?

    // MARK: - Initialization

    /// Creates a reader configured for the legacy Keychain services.
    ///
    /// - Parameters:
    ///   - accessGroup: The Keychain access group used by the legacy SDK, or `nil` for the default.
    ///   - logger: Logger for diagnostic output, or `nil` to suppress logging.
    init(accessGroup: String? = nil, logger: Logger? = nil) {
        self.accessGroup = accessGroup
        self.securedKey = LegacySecuredKey.load(accessGroup: accessGroup, logger: logger)
        self.logger = logger

        if securedKey != nil {
            logger?.i("Legacy SecuredKey found — data will be decrypted during migration")
        } else {
            logger?.i("No legacy SecuredKey found — data is not encrypted")
        }
    }

    // MARK: - Public Methods

    /// Checks whether any legacy account or mechanism data exists in the Keychain.
    ///
    /// This is a lightweight check that does not deserialize any data.
    ///
    /// - Returns: `true` if at least one account or mechanism entry exists.
    func legacyDataExists() -> Bool {
        let accountCount = itemCount(service: Self.accountService)
        let mechanismCount = itemCount(service: Self.mechanismService)
        logger?.d("Legacy Keychain item counts — accounts: \(accountCount), mechanisms: \(mechanismCount)")
        return accountCount > 0 || mechanismCount > 0
    }

    /// Reads and deserializes all legacy accounts from the Keychain.
    ///
    /// Individual items that fail decryption or deserialization are skipped (logged as warnings),
    /// matching the legacy SDK's graceful degradation behavior.
    ///
    /// - Returns: An array of ``LegacyAccountArchive`` instances.
    /// - Throws: ``AuthMigrationError/failedToReadLegacyData(_:)`` if the Keychain query fails.
    func getAllAccounts() throws -> [LegacyAccountArchive] {
        let dataItems = try readAllItems(service: Self.accountService)
        logger?.d("Read \(dataItems.count) raw account items from Keychain")
        return dataItems.enumerated().compactMap { index, data in
            logger?.d("Deserializing account [\(index)]: \(data.count) bytes")
            return deserializeAccount(data, index: index)
        }
    }

    /// Reads and deserializes all legacy mechanisms from the Keychain.
    ///
    /// - Returns: An array of ``LegacyMechanismArchive`` instances.
    /// - Throws: ``AuthMigrationError/failedToReadLegacyData(_:)`` if the Keychain query fails.
    func getAllMechanisms() throws -> [LegacyMechanismArchive] {
        let dataItems = try readAllItems(service: Self.mechanismService)
        logger?.d("Read \(dataItems.count) raw mechanism items from Keychain")
        return dataItems.enumerated().compactMap { index, data in
            logger?.d("Deserializing mechanism [\(index)]: \(data.count) bytes")
            return deserializeMechanism(data, index: index)
        }
    }

    /// Deletes all legacy data from all four Keychain services.
    ///
    /// Attempts to delete entries from account, mechanism, notification, and device token
    /// services. Individual delete failures are logged but do not throw.
    func deleteLegacyData() {
        deleteAllItems(service: Self.accountService)
        deleteAllItems(service: Self.mechanismService)
        deleteAllItems(service: Self.notificationService)
        deleteAllItems(service: Self.deviceTokenService)
    }

    // MARK: - Private Helpers

    /// Reads all raw `Data` items from a Keychain service.
    private func readAllItems(service: String) throws -> [Data] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw AuthMigrationError.failedToReadLegacyData(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }

        guard let items = result as? [Data] else {
            return []
        }

        return items
    }

    /// Optionally decrypts data if a SecuredKey is available.
    ///
    /// Matches the legacy SDK's fallback behavior: if decryption fails, the raw data
    /// is returned as-is. This handles the case where data was stored unencrypted
    /// despite a SecuredKey existing (e.g., encryption failed at write time).
    private func decryptIfNeeded(_ data: Data) -> Data {
        guard let securedKey = securedKey else {
            return data
        }
        if let decrypted = securedKey.decrypt(data) {
            return decrypted
        }
        // Fallback to raw data — matches legacy KeychainService.getData() behavior
        logger?.w("Decryption failed — falling back to raw data (\(data.count) bytes). "
                   + "Data may not have been encrypted.", error: nil)
        return data
    }

    /// Deserializes a single Account from raw Keychain data.
    private func deserializeAccount(_ data: Data, index: Int) -> LegacyAccountArchive? {
        let decrypted = decryptIfNeeded(data)

        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: decrypted)
        } catch {
            logger?.e("Account [\(index)]: Failed to create unarchiver — \(error.localizedDescription)", error: error)
            return nil
        }

        unarchiver.requiresSecureCoding = false
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(LegacyAccountArchive.self, forClassName: Self.legacyAccountClass)

        let account = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyAccountArchive
        unarchiver.finishDecoding()

        if let account = account {
            logger?.d("Account [\(index)]: Deserialized — issuer=\(account.issuer), accountName=\(account.accountName)")
        } else {
            logger?.w("Account [\(index)]: Failed to deserialize — skipping", error: nil)
        }

        return account
    }

    /// Deserializes a single Mechanism from raw Keychain data.
    private func deserializeMechanism(_ data: Data, index: Int) -> LegacyMechanismArchive? {
        let decrypted = decryptIfNeeded(data)

        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: decrypted)
        } catch {
            logger?.e("Mechanism [\(index)]: Failed to create unarchiver — \(error.localizedDescription)", error: error)
            return nil
        }

        unarchiver.requiresSecureCoding = false
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: Self.legacyTOTPClass)
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: Self.legacyHOTPClass)
        unarchiver.setClass(LegacyMechanismArchive.self, forClassName: Self.legacyPushClass)

        let mechanism = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyMechanismArchive
        unarchiver.finishDecoding()

        if let mechanism = mechanism {
            logger?.d("Mechanism [\(index)]: Deserialized — type=\(mechanism.type), "
                       + "issuer=\(mechanism.issuer), accountName=\(mechanism.accountName), "
                       + "uuid=\(mechanism.mechanismUUID)")
        } else {
            logger?.w("Mechanism [\(index)]: Failed to deserialize — skipping", error: nil)
        }

        return mechanism
    }

    /// Returns the number of items in a Keychain service.
    private func itemCount(service: String) -> Int {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [Data] {
            return items.count
        }
        return 0
    }

    /// Deletes all items from a Keychain service.
    private func deleteAllItems(service: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger?.w("Failed to delete items from \(service): OSStatus \(status)", error: nil)
        }
    }
}
