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

/// Policy that checks for device tampering indicators.
///
/// This is currently a placeholder implementation that always returns true.
/// In the future, this will be updated to use actual device tampering detection
/// similar to the legacy FRRootDetector with threshold scoring.
///
/// JSON format: {"deviceTampering": {"score": 0.8}}
///
/// The score threshold can be configured in the policy data. If the device
/// tampering score exceeds the threshold, the policy will fail.
public struct DeviceTamperingPolicy: MfaPolicy, Sendable {

    public static let policyName = "deviceTampering"
    private static let defaultThreshold: Double = 0.5

    public var name: String {
        return Self.policyName
    }

    public init() {}

    public func evaluate(data: [String: Any]?) async throws -> Bool {
        // TODO: Replace with actual device tampering detection
        // This is a placeholder implementation that always returns true

        // Get the threshold from policy configuration data
        let threshold = (data?["score"] as? Double) ?? Self.defaultThreshold

        // Placeholder: simulate device tampering score calculation
        // In real implementation, this would check for:
        // - Jailbreak detection
        // - Debug mode detection
        // - Simulator detection
        // - Hook framework detection (Frida, Cycript, etc.)
        // - Other tampering indicators
        let deviceTamperingScore = 0.0 // Always safe for now

        // Return true if device tampering score is below threshold
        return deviceTamperingScore < threshold
    }
}
