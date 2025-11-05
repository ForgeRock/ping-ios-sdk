//
//  PasswordCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects a password input from the user.
public class PasswordCallback: AbstractCallback, ObservableObject,  @unchecked Sendable {
    /// The prompt message displayed to the user.
    private(set) public var prompt: String = ""
    /// The password input collected from the user.
    public var password: String = ""
    
    /// Initializes a new instance of `PasswordCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        if name == JourneyConstants.prompt, let stringValue = value as? String {
            self.prompt = stringValue
        }
    }
    
    /// Returns the payload with the password value.
    public override func payload() -> [String: Any] {
        return input(password)
    }
}
