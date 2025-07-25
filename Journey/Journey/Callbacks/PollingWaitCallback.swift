//
//  PollingWaitCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that instructs an application to wait for the given period and resubmit the request.
public class PollingWaitCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// The period of time in milliseconds that the client should wait before replying to this callback
    private(set) public var waitTime: Int = 0
    /// The message which should be displayed to the user
    private(set) public var message: String = ""

    /// Initializes a new instance of `PollingWaitCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.waitTime:
            if let stringValue = value as? String, let intValue = Int(stringValue) {
                self.waitTime = intValue
            }
        case JourneyConstants.message:
            if let stringValue = value as? String {
                self.message = stringValue
            }
        default:
            break
        }
    }
}
