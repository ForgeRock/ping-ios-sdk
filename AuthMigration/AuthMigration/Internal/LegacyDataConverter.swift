//
//  LegacyDataConverter.swift
//  PingAuthMigration
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingCommons
import PingOath
import PingPush

/// Converts legacy `FRAuthenticator` data models to the new Ping SDK credential types.
///
/// `LegacyDataConverter` provides pure mapping functions that transform deserialized legacy
/// archives (``LegacyMechanismArchive`` and ``LegacyAccountArchive``) into ``OathCredential``
/// and ``PushCredential`` instances.
///
/// ## Field Mapping
///
/// Account metadata (display names, images, policies, lock state) is merged into each credential,
/// since the new storage model uses a 1-to-1 credential-per-mechanism structure rather than the
/// legacy's separate Account + Mechanism hierarchy.
///
/// ## Default Values
///
/// When legacy fields are missing or zero (as when `NSCoder` returns defaults for absent keys),
/// the converter applies sensible defaults:
/// - `digits`: `6` (if legacy value is `0`)
/// - `period`: `30` (if legacy value is `0`, TOTP only)
/// - `algorithm`: `.sha1` (if legacy value is nil)
/// - `platform`: `.pingAM` (Push credentials)
///
/// - SeeAlso: ``LegacyAccountArchive``
/// - SeeAlso: ``LegacyMechanismArchive``
internal struct LegacyDataConverter {

    // MARK: - Private Helpers

    /// Recodes a legacy base64url-encoded secret to standard base64 for the new PingPush SDK.
    ///
    /// The legacy iOS `FRAuthenticator` SDK stores the push shared secret in base64url format
    /// (with `-`/`_` characters and no `=` padding), exactly as received from the QR code URI.
    /// The new `PingPush` SDK expects standard base64 (with `+`/`/` characters and `=` padding).
    ///
    /// Falls back to the original string if decoding fails (e.g., already standard base64).
    private static func recodeSecretToStandardBase64(_ secret: String) -> String {
        if let data = Base64.decodeBase64UrlToData(secret) {
            return data.base64EncodedString()
        }
        return secret
    }

    /// Returns the account's `timeAdded` if it has a positive epoch value; otherwise falls back
    /// to the mechanism's `timeAdded`.
    private static func resolvedCreatedAt(
        account: LegacyAccountArchive,
        mechanism: LegacyMechanismArchive
    ) -> Date {
        account.timeAdded.timeIntervalSince1970 > 0
            ? account.timeAdded
            : mechanism.timeAdded
    }

    // MARK: - OATH

    /// Converts a legacy OATH mechanism and its parent account into an ``OathCredential``.
    ///
    /// - Parameters:
    ///   - mechanism: The deserialized legacy mechanism (type `"totp"` or `"hotp"`).
    ///   - account: The deserialized legacy account associated with this mechanism.
    /// - Returns: A fully populated ``OathCredential`` ready for storage.
    static func toOathCredential(
        mechanism: LegacyMechanismArchive,
        account: LegacyAccountArchive
    ) -> OathCredential {
        let oathType: OathType = mechanism.type.lowercased() == "hotp" ? .hotp : .totp

        let oathAlgorithm: OathAlgorithm = {
            switch mechanism.algorithm?.lowercased() {
            case "sha256": return .sha256
            case "sha512": return .sha512
            default: return .sha1
            }
        }()

        let digits = mechanism.digits > 0 ? mechanism.digits : 6
        let period = mechanism.period > 0 ? mechanism.period : 30
        let counter = mechanism.counter

        let createdAt = resolvedCreatedAt(account: account, mechanism: mechanism)

        return OathCredential(
            id: mechanism.mechanismUUID,
            userId: mechanism.uid,
            resourceId: mechanism.resourceId,
            issuer: account.issuer,
            displayIssuer: account.displayIssuer ?? account.issuer,
            accountName: account.accountName,
            displayAccountName: account.displayAccountName ?? account.accountName,
            oathType: oathType,
            oathAlgorithm: oathAlgorithm,
            digits: digits,
            period: oathType == .totp ? period : 0,
            counter: counter,
            createdAt: createdAt,
            imageURL: account.imageUrl,
            backgroundColor: account.backgroundColor,
            policies: account.policies,
            lockingPolicy: account.lockingPolicy,
            isLocked: account.lock,
            secretKey: mechanism.secret
        )
    }

    /// Converts a legacy Push mechanism and its parent account into a ``PushCredential``.
    ///
    /// The `authEndpoint` URL is stripped of query parameters to derive the `serverEndpoint`.
    /// For example, `https://am.example.com/json/push/sns/message?_action=authenticate`
    /// becomes `https://am.example.com/json/push/sns/message`.
    ///
    /// - Parameters:
    ///   - mechanism: The deserialized legacy mechanism (type `"push"`).
    ///   - account: The deserialized legacy account associated with this mechanism.
    /// - Returns: A fully populated ``PushCredential`` ready for storage.
    static func toPushCredential(
        mechanism: LegacyMechanismArchive,
        account: LegacyAccountArchive
    ) -> PushCredential {
        // Strip query parameters from authEndpoint to get serverEndpoint
        let rawEndpoint = mechanism.authEndpoint ?? ""
        let serverEndpoint: String
        if let questionMark = rawEndpoint.firstIndex(of: "?") {
            serverEndpoint = String(rawEndpoint[rawEndpoint.startIndex..<questionMark])
        } else {
            serverEndpoint = rawEndpoint
        }

        let createdAt = resolvedCreatedAt(account: account, mechanism: mechanism)

        return PushCredential(
            id: mechanism.mechanismUUID,
            userId: mechanism.uid,
            resourceId: mechanism.resourceId ?? mechanism.mechanismUUID,
            issuer: account.issuer,
            displayIssuer: account.displayIssuer ?? account.issuer,
            accountName: account.accountName,
            displayAccountName: account.displayAccountName ?? account.accountName,
            serverEndpoint: serverEndpoint,
            sharedSecret: recodeSecretToStandardBase64(mechanism.secret),
            createdAt: createdAt,
            imageURL: account.imageUrl,
            backgroundColor: account.backgroundColor,
            policies: account.policies,
            lockingPolicy: account.lockingPolicy,
            isLocked: account.lock,
            platform: .pingAM
        )
    }
}
