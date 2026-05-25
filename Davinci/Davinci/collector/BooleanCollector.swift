//
//  BooleanCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingDavinciPlugin

/// A collector representing a single checkbox field (e.g., agreement acceptance).
/// The value is a boolean indicating whether the checkbox is checked.
public class BooleanCollector: FieldCollector<Bool>, @unchecked Sendable {
    
    /// The appearance of the checkbox (CHECKBOX or SWITCH).
    public private(set) var appearance: BooleanCollectorAppearance = .checkbox
    
    /// The error message to display when validation fails.
    public private(set) var errorMessage: String?
    
    /// Optional rich content with template text and link replacements.
    public private(set) var richContent: RichContent?
    
    /// The current checked state of the checkbox.
    public var value: Bool = false
    
    /// Initializes a new instance of `BooleanCollector` with the given JSON input.
    public required init(with json: [String: Any]) {
        if let appearanceString = json[Constants.appearance] as? String,
           let parsedAppearance = BooleanCollectorAppearance(rawValue: appearanceString) {
            self.appearance = parsedAppearance
        } else {
            self.appearance = .checkbox
        }
        self.errorMessage = json[Constants.errorMessage] as? String
        
        if let richContentDict = json[Constants.richContent] as? [String: Any] {
            self.richContent = RichContent.parse(from: richContentDict)
        }
        
        super.init(with: json)
    }
    
    /// Initializes the collector with a pre-existing value.
    /// - Parameter value: A boolean value to set the checkbox state.
    public override func initialize(with value: Any) {
        if let boolValue = value as? Bool {
            self.value = boolValue
        }
    }
    
    /// Returns the boolean payload for form submission.
    override public func payload() -> Bool? {
        return value
    }
    
    /// Validates the checkbox. If required and unchecked, returns a validation error.
    public override func validate() -> [ValidationError] {
        var errors = [ValidationError]()
        
        if required && !value {
            if let message = errorMessage, !message.isEmpty {
                errors.append(.regexError(message: message))
            } else {
                errors.append(.required)
            }
        }
        
        return errors
    }
}

/// The appearance options for a single checkbox field.
/// - `checkbox`: A traditional checkbox appearance.
/// - `switch`: A switch/toggle appearance.
public enum BooleanCollectorAppearance: String, Sendable {
    case checkbox = "CHECKBOX"
    case `switch` = "SWITCH"
}
