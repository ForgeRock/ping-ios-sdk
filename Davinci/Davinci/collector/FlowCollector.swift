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
import PingDavinciPlugin
import PingOrchestrate

/// A collector for flow control actions, such as buttons or links.
///
/// This class is used to handle user interactions that trigger a flow action,
/// like navigating to a different part of the flow.
public class FlowCollector: SingleValueCollector, Submittable, Closeable, @unchecked Sendable {
    
    /// Resets the collector's state by clearing its value.
    public func close() {
        self.value = ""
    }
    
    /// Returns the event type for this collector.
    /// - Returns: A string representing the event type, which is "action".
    public func eventType() -> String {
        return Constants.ACTION.lowercased()
    }
}
