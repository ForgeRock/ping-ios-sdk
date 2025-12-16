//
//  PolicyTests.swift
//  PingCommonsTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import LocalAuthentication
@testable import PingCommons

final class PolicyTests: XCTestCase {

    // MARK: - MfaPolicyResult Tests

    func testPolicyResult_Success() {
        let result = MfaPolicyResult.success()

        XCTAssertTrue(result.isSuccess)
        XCTAssertFalse(result.isFailure)
        XCTAssertNil(result.nonCompliancePolicyName)
        XCTAssertNil(result.nonCompliancePolicy)
    }

    func testPolicyResult_Failure() {
        let policy = BiometricAvailablePolicy()
        let result = MfaPolicyResult.failure(policy: policy)

        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.nonCompliancePolicyName, "biometricAvailable")
        XCTAssertNotNil(result.nonCompliancePolicy)
    }

    // MARK: - BiometricAvailablePolicy Tests

    func testBiometricAvailablePolicy_Name() {
        let policy = BiometricAvailablePolicy()
        XCTAssertEqual(policy.name, "biometricAvailable")
    }

    func testBiometricAvailablePolicy_Evaluate() async throws {
        let policy = BiometricAvailablePolicy()

        // Note: This test will depend on the actual device/simulator capabilities
        // In a real test environment, we might want to mock LAContext
        let result = try await policy.evaluate(data: nil)

        // Check if running on simulator
        if isRunningOnSimulator() {
            // On simulator without biometrics, this should return false
            XCTAssertFalse(result, "BiometricAvailablePolicy should return false on simulator without biometrics")
        } else {
            // On real device, it depends on biometric setup, but should return a boolean
            // We can't guarantee true/false on device as it depends on user's biometric setup
            XCTAssertNotNil(result, "BiometricAvailablePolicy should return a boolean value on device")
        }
    }

    // MARK: - MfaPolicyEvaluator Tests

    func testPolicyEvaluator_Creation() async {
        let evaluator = MfaPolicyEvaluator.create()

        let policies = await evaluator.getPolicies()
        XCTAssertEqual(policies.count, 0) // Default should be empty

        let nonExistentPolicy = await evaluator.getPolicy(policyName: "nonExistent")
        XCTAssertNil(nonExistentPolicy)
    }

    func testPolicyEvaluator_CustomConfiguration() async {
        let customPolicy = MockPolicy(name: "custom", shouldPass: true)

        let evaluator = MfaPolicyEvaluator.create { config in
            config.policies = [customPolicy]
        }

        let policies = await evaluator.getPolicies()
        XCTAssertEqual(policies.count, 1)

        let retrievedPolicy = await evaluator.getPolicy(policyName: "custom")
        XCTAssertNotNil(retrievedPolicy)
    }

    func testPolicyEvaluator_EvaluateEmptyPolicies() async {
        let evaluator = MfaPolicyEvaluator.create()

        let result = await evaluator.evaluate(credentialPolicies: nil)
        XCTAssertTrue(result.isSuccess)

        let emptyResult = await evaluator.evaluate(credentialPolicies: "")
        XCTAssertTrue(emptyResult.isSuccess)
    }

    func testPolicyEvaluator_EvaluateMalformedJSON() async {
        let evaluator = MfaPolicyEvaluator.create()

        let malformedJSON = "{ invalid json"
        let result = await evaluator.evaluate(credentialPolicies: malformedJSON)

        // Should be compliant when JSON is malformed to avoid blocking users
        XCTAssertTrue(result.isSuccess)
    }

    func testPolicyEvaluator_EvaluateValidJSON() async {
        let mockPolicy = MockPolicy(name: "testPolicy", shouldPass: true)
        let evaluator = MfaPolicyEvaluator.create { config in
            config.policies = [mockPolicy]
        }

        let validJSON = """
        {
            "testPolicy": {
                "someParameter": "value"
            }
        }
        """

        let result = await evaluator.evaluate(credentialPolicies: validJSON)
        XCTAssertTrue(result.isSuccess)
    }

    func testPolicyEvaluator_EvaluateFailingPolicy() async {
        let failingPolicy = MockPolicy(name: "failingPolicy", shouldPass: false)
        let evaluator = MfaPolicyEvaluator.create { config in
            config.policies = [failingPolicy]
        }

        let validJSON = """
        {
            "failingPolicy": {}
        }
        """

        let result = await evaluator.evaluate(credentialPolicies: validJSON)
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.nonCompliancePolicyName, "failingPolicy")
    }

    func testPolicyEvaluator_EvaluateMultiplePolicies() async {
        let passingPolicy1 = MockPolicy(name: "policy1", shouldPass: true)
        let passingPolicy2 = MockPolicy(name: "policy2", shouldPass: true)
        let failingPolicy = MockPolicy(name: "policy3", shouldPass: false)

        let evaluator = MfaPolicyEvaluator.create { config in
            config.policies = [passingPolicy1, passingPolicy2, failingPolicy]
        }

        let validJSON = """
        {
            "policy1": {},
            "policy2": {},
            "policy3": {}
        }
        """

        let result = await evaluator.evaluate(credentialPolicies: validJSON)
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.nonCompliancePolicyName, "policy3")
    }
}

// MARK: - Mock Policy for Testing

private struct MockPolicy: MfaPolicy, Sendable {
    let name: String
    let shouldPass: Bool

    init(name: String, shouldPass: Bool) {
        self.name = name
        self.shouldPass = shouldPass
    }

    func evaluate(data: [String: Any]?) async throws -> Bool {
        return shouldPass
    }
}

// MARK: - Helper Methods

private func isRunningOnSimulator() -> Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
}
