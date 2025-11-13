//
//  ConfirmationCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Confirmation option type categories
public enum OptionType: Int {
    case unspecified = -1
    case yesNo = 0
    case yesNoCancel = 1
    case okCancel = 2
    case unknown
}

/// A callback that asks user for YES/NO, OK/CANCEL, YES/NO/CANCEL or other similar confirmations.
public class ConfirmationCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// An array of string for available option(s)
    private(set) public var options: [String] = []
    /// Default option
    private(set) public var defaultOption: OptionType = .unspecified
    /// Confirmation OptionType enum; defaulted to .unknown when the value is not provided
    private(set) public var optionType: OptionType = .unknown
    /// Confirmation MessageType enum; defaulted to .unknown when the value is not provided
    private(set) public var messageType: MessageType = .unknown
    /// String value of prompt attribute in Callback response; prompt is usually human readable text that can be displayed in UI
    private(set) public var prompt: String = ""
    /// A value provided from user interaction for this particular callback
    public var selectedIndex: Int?

    /// Initializes a new instance of `ConfirmationCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.prompt:
            if let stringValue = value as? String {
                self.prompt = stringValue
            }
        case JourneyConstants.messageType:
            if let intValue = value as? Int, let messageType = MessageType(rawValue: intValue) {
                self.messageType = messageType
            }
        case JourneyConstants.optionType:
            if let intValue = value as? Int, let optionType = OptionType(rawValue: intValue) {
                self.optionType = optionType
            }
        case JourneyConstants.options:
            if let arrayValue = value as? [String] {
                self.options = arrayValue
            }
        case JourneyConstants.defaultOption:
            if let intValue = value as? Int {
                self.defaultOption = OptionType(rawValue: intValue) ?? .unspecified
            }
        default:
            break
        }
    }
    
    /// Returns the payload with the user's selection value.
    public override func payload() -> [String: Any] {
        guard let selectedIndex = selectedIndex else {
            return json
        }
        return input(selectedIndex)
    }
}
