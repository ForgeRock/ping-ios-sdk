//
//  MfaPolicyEvaluator.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// The MFA Policy Evaluator is used by the SDK to enforce policy rules, such as device tampering
/// policy. It consists of one or more `MfaPolicy` objects. Each policy contains instructions that
/// determine whether it complies with a particular condition at a particular time.
///
/// This class provides a DSL-style configuration and can evaluate policies against credentials to
/// determine compliance.
public actor MfaPolicyEvaluator: Sendable {

    private let policies: [any MfaPolicy]
    private let logger: Logger

    private init(policies: [any MfaPolicy], logger: Logger) {
        self.policies = policies
        self.logger = logger
    }

    /// Evaluates policies for a credential with embedded policy configuration.
    ///
    /// - Parameter credentialPolicies: JSON string containing policy configurations from the credential.
    /// - Returns: `MfaPolicyResult` indicating compliance status.
    public func evaluate(credentialPolicies: String?) async -> MfaPolicyResult {
        guard let credentialPolicies = credentialPolicies, !credentialPolicies.isEmpty else {
            logger.d("No policies configured, considering compliant by default.")
            return MfaPolicyResult.success()
        }

        do {
            guard let data = credentialPolicies.data(using: .utf8),
                  let policiesJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.w("Malformed policies JSON, considering compliant to avoid blocking.", error: nil)
                return MfaPolicyResult.success()
            }

            return await evaluate(policiesJson: policiesJson)
        } catch {
            logger.w("Error parsing policies JSON: \(error.localizedDescription)", error: error)
            // If policies JSON is malformed, consider as compliant to avoid blocking
            return MfaPolicyResult.success()
        }
    }

    /// Evaluates policies against a JSON configuration.
    ///
    /// - Parameter policiesJson: Dictionary containing policy configurations.
    /// - Returns: `MfaPolicyResult` indicating compliance status.
    public func evaluate(policiesJson: [String: Any]) async -> MfaPolicyResult {
        for policy in policies {
            let policyName = policy.name

            // Check if this policy is configured in the JSON
            if policiesJson.keys.contains(policyName) {
                do {
                    // Get the policy data from JSON configuration
                    nonisolated(unsafe) let policyData = policiesJson[policyName] as? [String: Any]

                    // Evaluate the policy with data as parameter
                    let result = try await policy.evaluate(data: policyData)
                    if !result {
                        logger.d("Policy '\(policyName)' evaluation failed.")
                        return MfaPolicyResult.failure(policy: policy)
                    }
                } catch {
                    logger.w("Error evaluating policy '\(policyName)': \(error.localizedDescription)", error: error)
                    // If policy configuration is malformed, skip it
                    continue
                }
            }
        }

        logger.d("All policies evaluated successfully.")
        return MfaPolicyResult.success()
    }

    /// Returns all available policies in this evaluator.
    ///
    /// - Returns: An array of all configured policies.
    public func getPolicies() -> [any MfaPolicy] {
        return Array(policies)
    }

    /// Returns a specific policy by name.
    ///
    /// - Parameter policyName: The name of the policy to retrieve.
    /// - Returns: The policy with the given name, or nil if not found.
    public func getPolicy(policyName: String) -> (any MfaPolicy)? {
        return policies.first { $0.name == policyName }
    }
}

// MARK: - DSL Configuration
public extension MfaPolicyEvaluator {

    /// Configuration builder for `MfaPolicyEvaluator`.
    final class Config: @unchecked Sendable {
        public var policies: [any MfaPolicy] = []
        public var logger: Logger = LogManager.logger

        public init() {}
    }

    /// Creates a new `MfaPolicyEvaluator` using a DSL-style configuration.
    ///
    /// - Parameter configure: Configuration block for setting up the evaluator.
    /// - Returns: A new `MfaPolicyEvaluator` instance.
    static func create(configure: @Sendable (Config) -> Void = { _ in }) -> MfaPolicyEvaluator {
        let config = Config()
        configure(config)
        return MfaPolicyEvaluator(policies: config.policies, logger: config.logger)
    }
}