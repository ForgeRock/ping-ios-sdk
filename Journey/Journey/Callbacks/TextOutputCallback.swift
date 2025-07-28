//
//  TextOutputCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Message types for TextOutputCallback
public enum MessageType: Int {
    case information = 0
    case warning = 1
    case error = 2
    case unknown = -1
}

/// A callback that provides a message to be displayed to a user with given message type.
public class TextOutputCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// MessageType of Callback
    private(set) public var messageType: MessageType = .unknown
    /// String message to be displayed to a user
    private(set) public var message: String = ""
    
    /// Initializes a new instance of `TextOutputCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.message:
            if let stringValue = value as? String {
                self.message = stringValue
            }
        case JourneyConstants.messageType:
            if let stringValue = value as? String,
               let messageTypeInt = Int(stringValue),
               let messageType = MessageType(rawValue: messageTypeInt) {
                self.messageType = messageType
            }
        default:
            break
        }
    }
    
    /// Returns the original JSON payload as this callback doesn't require input.
    public override func payload() -> [String: Any] {
        return messageType == .unknown ? [:] : json
    }
}
