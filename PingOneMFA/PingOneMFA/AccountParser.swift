//
//  AccountParser.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Internal parser that converts the `deviceInfo` dictionary returned by `PingOne.getInfo(completion:)`
/// into a flat array of `PingOneMfaAccount` values.
///
/// The upstream payload has the shape:
/// ```
/// {
///   "NorthAmerica": {
///     "users": [
///       {
///         "id": "c845dcd4-...",
///         "device":      { "id": "05280532-..." },
///         "environment": { "id": "803ca4d4-..." }
///       }
///     ],
///     "deviceRequirementsEvaluation": { "status": "PASSED", ... },
///     "shouldRollback": 0
///   }
/// }
/// ```
/// The parser iterates the top-level keys as region names, walks `users[]`, and
/// flatMaps into `[PingOneMfaAccount]`.
/// Missing or malformed keys are silently skipped — the parser is best-effort and never throws.
internal struct AccountParser {

    /// Parses a `deviceInfo` dictionary (from `PingOne.getInfo(completion:)`) into
    /// a flat list of `PingOneMfaAccount` values.
    ///
    /// - Parameter deviceInfo: The raw dictionary returned by `PingOne.getInfo`. May be `nil`.
    /// - Returns: An array of parsed accounts (empty if `deviceInfo` is `nil`, empty, or malformed).
    internal static func parse(_ deviceInfo: [String: Any]?) -> [PingOneMfaAccount] {
        guard let deviceInfo = deviceInfo else { return [] }

        return deviceInfo.flatMap { (regionName, regionValue) -> [PingOneMfaAccount] in
            guard let regionDict = regionValue as? [String: Any],
                  let users = regionDict["users"] as? [[String: Any]] else {
                return []
            }
            return users.compactMap { userDict -> PingOneMfaAccount? in
                guard
                    let id = userDict["id"] as? String,
                    let deviceDict = userDict["device"] as? [String: Any],
                    let deviceId = deviceDict["id"] as? String,
                    let environmentDict = userDict["environment"] as? [String: Any],
                    let environmentId = environmentDict["id"] as? String
                else {
                    return nil
                }
                return PingOneMfaAccount(
                    region: regionName,
                    id: id,
                    deviceId: deviceId,
                    environmentId: environmentId
                )
            }
        }
    }
}
