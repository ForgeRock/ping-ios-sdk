//
//  ConsentMappingCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A callback that collects consent mapping information from a user.
public class ConsentMappingCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    /// The name of the consent mapping
    private(set) public var name: String = ""
    /// The display name of the consent mapping
    private(set) public var displayName: String = ""
    /// The icon associated with the consent mapping
    private(set) public var icon: String = ""
    /// The access level required for the consent mapping
    private(set) public var accessLevel: String = ""
    /// Whether the consent mapping is required
    private(set) public var isRequired: Bool = false
    /// The list of fields associated with the consent mapping
    private(set) public var fields: [String] = []
    /// The message to be displayed to the user
    private(set) public var message: String = ""
    /// Whether the user accepts the consent mapping
    public var accepted: Bool = false
    
    /// Initializes a new instance of `ConsentMappingCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.name:
            if let stringValue = value as? String {
                self.name = stringValue
            }
        case JourneyConstants.displayName:
            if let stringValue = value as? String {
                self.displayName = stringValue
            }
        case JourneyConstants.icon:
            if let stringValue = value as? String {
                self.icon = stringValue
            }
        case JourneyConstants.accessLevel:
            if let stringValue = value as? String {
                self.accessLevel = stringValue
            }
        case JourneyConstants.isRequired:
            if let boolValue = value as? Bool {
                self.isRequired = boolValue
            }
        case JourneyConstants.fields:
            if let arrayValue = value as? [String] {
                self.fields = arrayValue
            }
        case JourneyConstants.message:
            if let stringValue = value as? String {
                self.message = stringValue
            }
        default:
            break
        }
    }
    
    /// Returns the payload with the user's consent acceptance value.
    public override func payload() -> [String: Any] {
        return input(accepted)
    }
}
