//
//  FieldCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Abstract class representing a field collector.
/// - property type: The type of the field collector.
/// - property key: The key of the field collector.
/// - property label: The label of the field collector.
/// - property id The UUID of the field collector.
open class FieldCollector: Collector, @unchecked Sendable {
    public private(set) var type: String = ""
    public private(set) var key: String = ""
    public private(set) var label: String = ""
    public let id = UUID()
    
    /// Initializes a new instance of `FieldCollector`.
    public init() {}
    
    /// Initializes a new instance of `FieldCollector`.
    /// - Parameter json: The json to initialize from.
    required public init(with json: [String: Any]) {
        type = json[Constants.type] as? String ?? ""
        key = json[Constants.key] as? String ?? ""
        label = json[Constants.label] as? String ?? ""
    }
    
    /// Initializes `FieldCollector` with the given value.
    /// This implementation does nothing.
    /// Subclasses should override this method as needed.
    /// - Parameter input: The value to initialize with.
    public func initialize(with value: Any) {
        // To be implemented by subclasses
    }
}


/// Struct representing the validation of the field collector.
/// - property regex: The regex of the validation.
/// - property errorMessage: The error message of the validation.
public struct Validation {
    public let regex: NSRegularExpression?
    public let errorMessage: String
    
    /// Initializes a new instance of `Validation`.
    /// - Parameters:
    ///   - regexPattern: The regex pattern.
    ///   - errorMessage: The error message.
    public init(regexPattern: String, errorMessage: String) {
        self.regex = try? NSRegularExpression(pattern: regexPattern)
        self.errorMessage = errorMessage
    }
}
