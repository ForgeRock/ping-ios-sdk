//
//  TermsAndConditionsCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects a user's acceptance of the configured Terms & Conditions.
public class TermsAndConditionsCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// Created date of given Terms & Conditions in string
    private(set) public var createDate: String = ""
    /// String value of Terms & Conditions
    private(set) public var terms: String = ""
    /// Specified version of given Terms & Conditions
    private(set) public var version: String = ""
    /// The user's acceptance of the terms and conditions
    public var accepted: Bool = false
    
    /// Initializes a new instance of `TermsAndConditionsCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.version:
            if let stringValue = value as? String {
                self.version = stringValue
            }
        case JourneyConstants.createDate:
            if let stringValue = value as? String {
                self.createDate = stringValue
            }
        case JourneyConstants.terms:
            if let stringValue = value as? String {
                self.terms = stringValue
            }
        default:
            break
        }
    }
    
    /// Returns the payload with the user's acceptance value.
    public override func payload() -> [String: Any] {
        return input(accepted)
    }
}
