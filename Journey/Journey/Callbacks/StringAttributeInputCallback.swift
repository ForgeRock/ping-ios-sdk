//
//  StringAttributeInputCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// A callback that collects a single string user attribute with validation against given policies.
public class StringAttributeInputCallback: AttributeInputCallback, @unchecked Sendable {
    /// The string value input collected from the user.
    public var value: String = ""
    
    /// Initializes a new instance of `StringAttributeInputCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        
        if name == JourneyConstants.value, let stringValue = value as? String {
            self.value = stringValue
        }
    }
    
    /// Returns the payload with the string value and validation values.
    public override func payload() -> [String: Any] {
        return input(value, validateOnly)
    }
}
