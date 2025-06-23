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

public class NameCallback: AbstractCallback<String>, ObservableObject, @unchecked Sendable {
    
    private(set) public var prompt: String = ""
    public var name: String = ""

    public override func initValue(name: String, value: Any) {
        if name == "prompt", let stringValue = value as? String {
            self.prompt = stringValue
        }
    }

    public override func payload() -> [String: Any] {
        return input(name)
    }
}
