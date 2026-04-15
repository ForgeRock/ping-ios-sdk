//
//  ValidatedPasswordCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// A callback that collects a password with validation against given policies.
public class ValidatedPasswordCallback: AbstractValidatedCallback, @unchecked Sendable {
    /// Boolean indicator whether or not to display input value
    private(set) public var echoOn: Bool = false
    /// The password input collected from the user.
    public var password: String = ""
    
    /// Initializes a new instance of `ValidatedCreatePasswordCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        switch name {
        case JourneyConstants.echoOn:
            if let boolValue = value as? Bool {
                self.echoOn = boolValue
            }
        default:
            break
        }
    }
    
    /// Returns the payload with the password and validation values.
    public override func payload() -> [String: Any] {
        return input(password, validateOnly)
    }
}
