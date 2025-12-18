//
//  DeviceTamperingPolicyTests.swift
//  DeviceTamperingTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import LocalAuthentication
@testable import PingTamperDetector

final class DeviceTamperingPolicyTests: XCTestCase {
    
    // MARK: - DeviceTamperingPolicy Tests
    
    func testDeviceTamperingPolicy_Name() {
        let policy = DeviceTamperingPolicy()
        XCTAssertEqual(policy.name, "deviceTampering")
    }
    
    func testDeviceTamperingPolicy_EvaluateWithoutData() async throws {
        let policy = DeviceTamperingPolicy()
        
        let result = try await policy.evaluate(data: nil)
        
        // Should return true (compliant) with placeholder implementation
        XCTAssertTrue(result)
    }
    
    func testDeviceTamperingPolicy_EvaluateWithThreshold() async throws {
        let policy = DeviceTamperingPolicy()
        
        // Test with high threshold (should pass)
        let highThresholdData = ["score": 0.9]
        let resultHigh = try await policy.evaluate(data: highThresholdData)
        XCTAssertTrue(resultHigh)
        
        // Test with low threshold (should still pass with placeholder score of 0.0)
        let lowThresholdData = ["score": 0.1]
        let resultLow = try await policy.evaluate(data: lowThresholdData)
        XCTAssertTrue(resultLow)
    }
    
}
