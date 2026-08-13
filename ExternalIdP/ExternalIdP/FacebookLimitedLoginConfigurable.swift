//
//  FacebookLimitedLoginConfigurable.swift
//  ExternalIdP
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Adopted by Facebook handlers to expose Limited Login toggling across module boundaries
/// without importing `PingExternalIdPFacebook`. `IdpCallback` and `IdpCollector` construct
/// the concrete handler via `NSClassFromString(...)` and cast to this protocol to set the flag
/// with compile-time-checked types instead of `setValue(_:forKey:)`.
///
/// `@MainActor` is required here for Swift 6 strict-concurrency correctness: both concrete
/// conformers (`FacebookHandler`, `FacebookRequestHandler`) are `@MainActor` classes, so their
/// `facebookLimitedLoginEnabled` property is actor-isolated. Without `@MainActor` on the
/// protocol requirement, the Swift 6 compiler raises
/// "main actor-isolated property cannot satisfy nonisolated protocol requirement".
@MainActor
@objc public protocol FacebookLimitedLoginConfigurable {
    @objc var facebookLimitedLoginEnabled: Bool { get set }
}
