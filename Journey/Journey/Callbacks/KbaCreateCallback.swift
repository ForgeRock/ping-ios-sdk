//
//  KbaCreateCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that is responsible to define and create Knowledge Based Authentication question and answer for a user.
public class KbaCreateCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    // The prompt message displayed to the user for input.
    private(set) public var prompt: String = ""
    /// An array of predefined knowledge based authentication questions
    private(set) public var predefinedQuestions: [String] = []
    /// A string value of the selected question from the user interaction
    public var selectedQuestion: String = ""
    /// A string value of the answer from the user interaction
    public var selectedAnswer: String = ""
    
    /// Initializes a new instance of `KbaCreateCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.prompt:
            if let stringValue = value as? String {
                self.prompt = stringValue
            }
        case JourneyConstants.predefinedQuestions:
            if let arrayValue = value as? [String] {
                self.predefinedQuestions = arrayValue
            }
        default:
            break
        }
    }
    
    /// Returns the payload with the question and answer values.
    public override func payload() -> [String: Any] {
        return input(selectedQuestion, selectedAnswer)
    }
}
