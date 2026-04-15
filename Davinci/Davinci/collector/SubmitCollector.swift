// 
//  SubmitCollector.swift
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

/// A collector for form submission actions.
///
/// This class is used to handle the submission of a form, triggering the next step in the flow.
public class SubmitCollector: SingleValueCollector, Submittable, Closeable, @unchecked Sendable {
    
    /// Resets the collector's state by clearing its value.
    public func close() {
        self.value = ""
    }
    
    /// Returns the event type for this collector.
    /// - Returns: A string representing the event type, which is "submit".
    public func eventType() -> String {
        return Constants.submit
    }
}
