//
//  ValidatedUsernameCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects a username with validation against given policies.
public class ValidatedUsernameCallback: AbstractValidatedCallback, @unchecked Sendable {
    /// The username input collected from the user.
    public var username: String = ""
    
    /// Initializes a new instance of `ValidatedCreateUsernameCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
    }
    
    /// Returns the payload with the username and validation values.
    public override func payload() -> [String: Any] {
        return input(username, validateOnly)
    }
}
