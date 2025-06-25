//
//  NameCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

// A callback that collects a name input from the user.
public class NameCallback: AbstractCallback<String>, ObservableObject, @unchecked Sendable {
    /// The prompt message displayed to the user for input.
    private(set) public var prompt: String = ""
    /// The name of the input field.
    public var name: String = ""

    /// Initializes a new instance of `NameCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        if name == "prompt", let stringValue = value as? String {
            self.prompt = stringValue
        }
    }

    /// Initializes a new instance of `NameCallback` with the given JSON input.
    public override func payload() -> [String: Any] {
        return input(name)
    }
}
