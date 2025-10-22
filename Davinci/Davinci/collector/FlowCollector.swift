// 
//  FlowCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Representing a FLOW_BUTTON, FLOW_LINK Type.
/// This class inherits from the `SingleValueCollector` class and implements the `Collector` protocol.
/// It is used to collect data in a flow.
public class FlowCollector: SingleValueCollector, Submittable, @unchecked Sendable {
    /// Return event type
    public func eventType() -> String {
        return Constants.ACTION.lowercased()
    }
}
