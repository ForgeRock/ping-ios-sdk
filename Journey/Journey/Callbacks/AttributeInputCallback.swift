//
//  AttributeInputCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// Base implementation of a callback for collection of a single identity object attribute from a user.
public class AttributeInputCallback: AbstractValidatedCallback, @unchecked Sendable {
    /// Name of given attribute
    private(set) public var name: String = ""
    /// Boolean indicator whether given attribute is required or not
    private(set) public var required: Bool = false
    
    /// Initializes a new instance of `AttributeInputCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        
        switch name {
        case JourneyConstants.name:
            if let stringValue = value as? String {
                self.name = stringValue
            }
        case JourneyConstants.required:
            if let boolValue = value as? Bool {
                self.required = boolValue
            }
        default:
            break
        }
    }
}
