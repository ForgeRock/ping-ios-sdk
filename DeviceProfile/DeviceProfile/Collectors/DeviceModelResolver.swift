//
//  DeviceModelResolver.swift
//  DeviceProfile
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

// MARK: - DeviceModelResolver

/// Resolves Apple hardware model identifiers to their commercial (marketing)
/// device names.
///
/// The input is the raw `uname(3)` `machine` string as captured by
/// `PlatformInfo.getDeviceModel()` (e.g. `"iPhone15,2"`); the output is the
/// matching commercial name (e.g. `"iPhone 14 Pro"`), looked up in the static
/// `DeviceModelCatalog`.
///
/// Lookup semantics:
/// - Exact and case-sensitive: no normalization, no prefix matching, no
///   closest-generation fallback. `uname().machine` produces a canonical
///   casing on real hardware, so normalization would only mask catalog bugs.
/// - `nil` for any identifier absent from the catalog — including Simulator
///   machine strings (`"arm64"`, `"x86_64"`, `"i386"`), Mac identifiers, and
///   hardware released after the catalog was generated. An unknown identifier
///   is an expected, non-error outcome, not a failure.
///
/// Example:
/// ```swift
/// DeviceModelResolver.commercialName(for: "iPhone15,2") // "iPhone 14 Pro"
/// DeviceModelResolver.commercialName(for: "iphone15,2") // nil (case-sensitive)
/// DeviceModelResolver.commercialName(for: "arm64")      // nil (Simulator)
/// ```
public enum DeviceModelResolver: Sendable {

    /// Returns the commercial (marketing) name for the given hardware model
    /// identifier, or `nil` if the identifier is not in the catalog.
    /// - Parameter identifier: The raw model identifier (e.g. `"iPhone15,2"`).
    /// - Returns: The commercial name (e.g. `"iPhone 14 Pro"`), or `nil`.
    public static func commercialName(for identifier: String) -> String? {
        DeviceModelCatalog.identifierToCommercialName[identifier]
    }
}
