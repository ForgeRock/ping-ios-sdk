//
//  NumberAttributeInputCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// A callback that collects a double value user attribute with validation against given policies.
public class NumberAttributeInputCallback: AttributeInputCallback, @unchecked Sendable {
    /// The number value input collected from the user.
    public var value: Double = 0.0
    
    /// Initializes a new instance of `NumberAttributeInputCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        
        if name == JourneyConstants.value {
            if let doubleValue = value as? Double {
                self.value = doubleValue
            } else if let intValue = value as? Int {
                self.value = Double(intValue)
            } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                self.value = doubleValue
            }
        }
    }
    
    /// Returns the payload with the number value and validation values.
    public override func payload() -> [String: Any] {
        return input(value, validateOnly)
    }
}
