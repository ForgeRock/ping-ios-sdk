// 
//  Submittable.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// A protocol describing a self-submittable collector or control.
///
/// Types conforming to `Submittable` can provide their own event type
/// to be used when constructing the payload for a "continue" or equivalent submission.
public protocol Submittable {
    /// Returns the event type string to use for submission.
    func eventType() -> String
}

/// Adopted by collectors that supply an `actionKey` directly rather than contributing to `formData`.
/// Used by the FIDO error path to propagate WebAuthn DOMException names to the DaVinci server.
public protocol ActionKeyProvider {
    var actionKey: String? { get }
}

