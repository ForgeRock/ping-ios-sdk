//
//  LegacySecuredKey.swift
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

/// Reads the legacy Secure Enclave key used by `FRAuthenticator` for Keychain data encryption,
/// and provides decryption of data encrypted by the legacy SDK.
///
/// `LegacySecuredKey` is a **read-only** wrapper. It locates an existing EC key pair in the
/// Keychain using the legacy application tag, obtains the public key from the private key,
/// and decrypts data using the same algorithm the legacy SDK used for encryption.
///
/// The legacy `FRAuthenticator` SDK uses:
/// - **Key type:** EC 256-bit, Secure Enclave–backed
/// - **Application tag:** `com.forgerock.ios.authenticator.securedKey.identifier`
/// - **Encryption algorithm (current):** `eciesEncryptionCofactorVariableIVX963SHA256AESGCM`
/// - **Encryption algorithm (legacy fallback):** `eciesEncryptionCofactorX963SHA256AESGCM`
///
/// ## Decryption Algorithm
///
/// The decryption tries the current algorithm first. If that fails, it falls back to the
/// legacy algorithm, matching the behavior in `FRCore.SecuredKey.decrypt(_:)`.
///
/// - SeeAlso: ``LegacyKeychainReader``
internal struct LegacySecuredKey {

    /// The default Keychain application tag used by `FRAuthenticator`'s `SecuredKey`.
    static let defaultApplicationTag = "com.forgerock.ios.authenticator.securedKey.identifier"

    /// The current encryption/decryption algorithm used by the legacy SDK.
    private static let currentAlgorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM

    /// The legacy fallback algorithm for older data.
    private static let legacyAlgorithm: SecKeyAlgorithm = .eciesEncryptionCofactorX963SHA256AESGCM

    /// The private key reference from the Keychain. Used for decryption.
    private let privateKey: SecKey

    /// Logger for diagnostic output.
    private let logger: Logger?

    /// Attempts to load the legacy Secure Enclave key from the Keychain.
    ///
    /// Queries the Keychain for an existing EC key pair with the given application tag.
    /// Returns `nil` if no key exists (meaning the legacy SDK did not use encryption).
    ///
    /// - Parameters:
    ///   - applicationTag: The Keychain application tag for the legacy key.
    ///     Defaults to ``defaultApplicationTag``.
    ///   - accessGroup: The Keychain access group, if the legacy SDK was configured with one.
    ///   - logger: Logger for diagnostic output, or `nil` to suppress logging.
    /// - Returns: A `LegacySecuredKey` if the key exists, or `nil` if not found.
    static func load(
        applicationTag: String = defaultApplicationTag,
        accessGroup: String? = nil,
        logger: Logger? = nil
    ) -> LegacySecuredKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let result = result else {
            logger?.d("No legacy SecuredKey found in Keychain (OSStatus: \(status))")
            return nil
        }

        // result is typed as AnyObject; verify it is actually a SecKey via CFTypeID comparison
        guard CFGetTypeID(result) == SecKeyGetTypeID() else {
            logger?.w("Keychain returned non-SecKey object for legacy key tag", error: nil)
            return nil
        }

        let privateKey = unsafeDowncast(result, to: SecKey.self)
        logger?.d("Legacy SecuredKey loaded successfully")

        return LegacySecuredKey(privateKey: privateKey, logger: logger)
    }

    /// Attempts to decrypt data that was encrypted by the legacy SDK's `SecuredKey`.
    ///
    /// Tries the current algorithm first (``eciesEncryptionCofactorVariableIVX963SHA256AESGCM``).
    /// If that fails, falls back to the legacy algorithm
    /// (``eciesEncryptionCofactorX963SHA256AESGCM``), matching the behavior of the
    /// legacy `FRCore.SecuredKey.decrypt(_:)` method.
    ///
    /// Returns `nil` if both algorithms fail, matching the legacy SDK's behavior where
    /// callers fall back to using the raw (unencrypted) data.
    ///
    /// - Parameter data: The potentially encrypted `Data` blob from the Keychain.
    /// - Returns: The decrypted `Data`, or `nil` if decryption failed with both algorithms.
    func decrypt(_ data: Data) -> Data? {
        logger?.d("Attempting decryption of \(data.count)-byte payload")

        // Try current algorithm first
        var error: Unmanaged<CFError>?
        if let decrypted = SecKeyCreateDecryptedData(privateKey, Self.currentAlgorithm, data as CFData, &error) {
            logger?.d("Decryption succeeded with current algorithm (\(data.count) -> \((decrypted as Data).count) bytes)")
            return decrypted as Data
        }

        // Log the first failure
        let firstErrorDesc: String
        if let firstError = error {
            let cfError = firstError.takeRetainedValue()
            firstErrorDesc = (cfError as Error).localizedDescription
            error = nil
        } else {
            firstErrorDesc = "unknown error"
        }
        logger?.d("Current algorithm failed: \(firstErrorDesc) — trying legacy algorithm")

        // Fallback to legacy algorithm
        if let decrypted = SecKeyCreateDecryptedData(privateKey, Self.legacyAlgorithm, data as CFData, &error) {
            logger?.d("Decryption succeeded with legacy algorithm (\(data.count) -> \((decrypted as Data).count) bytes)")
            return decrypted as Data
        }

        // Both failed
        let secondErrorDesc: String
        if let secondError = error {
            let cfError = secondError.takeRetainedValue()
            secondErrorDesc = (cfError as Error).localizedDescription
        } else {
            secondErrorDesc = "unknown error"
        }
        logger?.w("Decryption failed with both algorithms for \(data.count)-byte payload. "
                   + "Current: \(firstErrorDesc). Legacy: \(secondErrorDesc)", error: nil)

        return nil
    }
}
