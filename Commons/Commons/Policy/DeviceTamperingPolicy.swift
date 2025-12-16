//
//  DeviceTamperingPolicy.swift
//  PingCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingTamperDetector

/// Policy that checks for device tampering indicators.
///
/// Uses the TamperDetector module to analyze the device for signs of jailbreaking
/// and compares the result against a configurable threshold.
///
/// JSON format: {"deviceTampering": {"score": 0.8}}
///
/// The score threshold can be configured in the policy data. If the device
/// tampering score exceeds or equals the threshold, the policy will fail.
/// Default threshold is 0.8 (matching Android implementation).
public struct DeviceTamperingPolicy: MfaPolicy, Sendable {

    public static let policyName = "deviceTampering"
    private static let defaultThreshold: Double = 0.8

    public var name: String {
        return Self.policyName
    }

    public init() {}

    public func evaluate(data: [String: Any]?) async throws -> Bool {
        // Get the threshold from policy configuration data
        // Default to 0.8 to match Android implementation
        let threshold = (data?["score"] as? Double) ?? Self.defaultThreshold

        // Use TamperDetector to analyze device for tampering
        // Must call on main actor since TamperDetector requires it
        let deviceTamperingScore = await MainActor.run {
            let tamperDetector = TamperDetector()
            return tamperDetector.analyze()
        }

        // Return true (compliant) if device tampering score is below threshold
        // Return false (non-compliant) if score meets or exceeds threshold
        return deviceTamperingScore < threshold
    }
}
