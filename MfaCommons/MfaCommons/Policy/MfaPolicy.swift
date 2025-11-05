//
//  MfaPolicy.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Base protocol for all MFA policies.
/// 
/// MFA policies enforce security requirements before allowing credential operations.
/// Each policy can evaluate device state and return whether the current conditions meet security requirements.
public protocol MfaPolicy: Sendable {

    /// The unique name identifier for this policy.
    var name: String { get }

    /// Evaluates this policy against the current device context.
    /// - Parameter data: Configuration data for this policy, parsed from a JSON policies string.
    /// - Returns: `true` if the policy requirements are met, `false` otherwise.
    func evaluate(data: [String: Any]?) async throws -> Bool
}

/// Default implementations and utilities for `MfaPolicy`.
public extension MfaPolicy {

    /// A string representation of this policy.
    var description: String {
        return "\(type(of: self))(name: '\(name)')"
    }
}
