//
//  HiddenValueCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin

/// A callback that handles hidden values in the authentication flow.
public class HiddenValueCallback: AbstractCallback, HiddenValueCallbackProtocol, ObservableObject, @unchecked Sendable {
    /// Hidden identifier value
    public var hiddenId: String = ""
    /// The hidden value to be sent back
    public var value: String = ""
    
    /// Initializes a new instance of `HiddenValueCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.id:
            if let stringValue = value as? String {
                self.hiddenId = stringValue
            }
        case JourneyConstants.value:
            if let stringValue = value as? String {
                self.value = stringValue
            }
        default:
            break
        }
    }
    
    /// Convinience Method for setting the value
    /// - Parameters:
    ///   - value: Value of the input to be updated
    public func setValue(_ value: String) {
        self.value = value
    }
    
    /// Returns the payload with the hidden value.
    public override func payload() -> [String: Any] {
        return input(value)
    }
}
