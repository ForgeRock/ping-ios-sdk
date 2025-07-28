//
//  TextInputCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects a text input from the user.
public class TextInputCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// The prompt message displayed to the user.
    private(set) public var prompt: String = ""
    /// Default text value for the input field.
    private(set) public var defaultText: String = ""
    /// The text input collected from the user.
    public var text: String = ""

    /// Initializes a new instance of `TextInputCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.prompt:
            if let stringValue = value as? String {
                self.prompt = stringValue
            }
        case JourneyConstants.defaultText:
            if let stringValue = value as? String {
                self.defaultText = stringValue
                self.text = stringValue // Set default text as initial value
            }
        default:
            break
        }
    }

    /// Returns the payload with the text input value.
    public override func payload() -> [String: Any] {
        return input(text)
    }
}
