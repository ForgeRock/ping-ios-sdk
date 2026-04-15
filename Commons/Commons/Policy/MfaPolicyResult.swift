//
//  MfaPolicyResult.swift
//  PingCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents the result of policy evaluation for a credential.
/// Encapsulates both the compliance status and identifies
/// which policy (if any) caused non-compliance.
public struct MfaPolicyResult: Sendable {

    private let isCompliant: Bool
    private let nonComplianceMfaPolicy: (any MfaPolicy)?

    private init(isCompliant: Bool, nonComplianceMfaPolicy: (any MfaPolicy)? = nil) {
        self.isCompliant = isCompliant
        self.nonComplianceMfaPolicy = nonComplianceMfaPolicy
    }

    /// Returns true if the credential is compliant with all policies.
    public var isSuccess: Bool {
        isCompliant
    }

    /// Returns true if the credential failed at least one policy.
    public var isFailure: Bool {
        !isCompliant
    }

    /// The name of the non-compliant policy, or nil if compliant.
    public var nonCompliancePolicyName: String? {
        nonComplianceMfaPolicy?.name
    }

    /// The non-compliant policy instance, or nil if compliant.
    public var nonCompliancePolicy: (any MfaPolicy)? {
        nonComplianceMfaPolicy
    }
}

// MARK: - Factory Methods
public extension MfaPolicyResult {

    /// Creates a successful policy evaluation result.
    /// - Returns: A compliant `MfaPolicyResult`.
    static func success() -> MfaPolicyResult {
        MfaPolicyResult(isCompliant: true)
    }

    /// Creates a failed policy evaluation result.
    /// - Parameter policy: The policy that failed evaluation.
    /// - Returns: A non-compliant `MfaPolicyResult`.
    static func failure(policy: any MfaPolicy) -> MfaPolicyResult {
        MfaPolicyResult(isCompliant: false, nonComplianceMfaPolicy: policy)
    }
}
