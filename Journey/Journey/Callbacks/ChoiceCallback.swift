//
//  ChoiceCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects single user input from available choices, with predefined default choice.
public class ChoiceCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// List of available options for ChoiceCallback
    private(set) public var choices: [String] = []
    /// Default choice value defined from OpenAM
    private(set) public var defaultChoice: Int = 0
    /// The prompt message displayed to the user
    private(set) public var prompt: String = ""
    /// The selected choice index
    public var selectedIndex: Int = 0

    /// Initializes a new instance of `ChoiceCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.prompt:
            if let stringValue = value as? String {
                self.prompt = stringValue
            }
        case JourneyConstants.choices:
            if let arrayValue = value as? [String] {
                self.choices = arrayValue
            }
        case JourneyConstants.defaultChoice:
            if let intValue = value as? Int {
                self.defaultChoice = intValue
                self.selectedIndex = intValue // Set default selection
            }
        default:
            break
        }
    }

    /// Returns the payload with the selected choice value.
    public override func payload() -> [String: Any] {
        return input(selectedIndex)
    }
}
