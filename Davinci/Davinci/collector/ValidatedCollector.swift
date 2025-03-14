//
//  ValidatedCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Open class representing a validated collector.
open class ValidatedCollector: SingleValueCollector, @unchecked Sendable {
    /// Holds a validation object. Only writable within this class.
    public private(set) var validation: Validation?
    /// Flag indicating whether the field is required. Only writable within this class.
    public private(set) var required: Bool = false
    
    /// Initializes the `ValidatedCollector` with the given input.
    /// - Parameter json: A dictionary representing the JSON element to parse.
    public required init(with json: [String : Any]) {
        super.init(with :json)
        
        // Parse the "required" field
        required = json[Constants.required] as? Bool ?? false
        
        // Parse the validation object
        if let validationDict = json[Constants.validation] as? [String: Any],
           let regexPattern = validationDict[Constants.regex] as? String, !regexPattern.isEmpty {
            let errorMessage = validationDict[Constants.errorMessage] as? String ?? ""
            validation = Validation(
                regexPattern: regexPattern,
                errorMessage: errorMessage
            )
        }
    }
    
    /// Validates the collector’s value and returns a list of validation errors, if any.
    /// - Returns: An array of `ValidationError`.
    open func validate() -> [ValidationError] {
        var errors = [ValidationError]()
        
        // Check if the field is required but empty
        if required && value.isEmpty {
            errors.append(.required)
        }
        
        // Check regex validation if provided
        if let validation = validation, let regex = validation.regex {
            if regex.firstMatch(in: value, range: NSRange(location: 0, length: value.utf16.count)) == nil {
                errors.append(.regexError(message: validation.errorMessage))
            }
        }
        
        return errors
    }
}
