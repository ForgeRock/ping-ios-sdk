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
import PingDavinciPlugin


/// Abstract class representing a field collector.
/// - property type: The type of the field collector.
/// - property key: The key of the field collector.
/// - property label: The label of the field collector.
/// - property id The UUID of the field collector.
open class FieldCollector<T>: Collector, AnyFieldCollector, Validator, @unchecked Sendable {
    public private(set) var type: String = ""
    public private(set) var key: String = ""
    public private(set) var label: String = ""
    public private(set) var required: Bool = false
    public var id: String {
        return key
    }
    
    /// Initializes a new instance of `FieldCollector`.
    public init() {}
    
    /// Initializes a new instance of `FieldCollector`.
    /// - Parameter json: The json to initialize from.
    required public init(with json: [String: Any]) {
        type = json[Constants.type] as? String ?? ""
        key = json[Constants.key] as? String ?? ""
        label = json[Constants.label] as? String ?? ""
        required = json[Constants.required] as? Bool ?? false
    }
    
    /// Initializes `FieldCollector` with the given value.
    /// This implementation does nothing.
    /// Subclasses should override this method as needed.
    /// - Parameter input: The value to initialize with.
    public func initialize(with value: Any) {
        // To be implemented by subclasses
    }
    
    /// Validates the field collector. Returns an array of validation errors.
    public func validate() -> [ValidationError] {
        var errors = [ValidationError]()
        if (required && payload() == nil) {
            errors.append(.required)
        }
        return errors
    }
    
    /// Function returning the `Payload` of the FieldCollector.
    open func payload() -> T? {
        fatalError("Subclasses need to override the payload() method.")
    }
    
    /// Type-erased version of payload()
    public func anyPayload() -> Any? {
        return payload()
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
