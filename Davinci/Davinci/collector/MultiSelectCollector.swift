//
//  MultiSelectCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Class representing CHECKBOX, COMBOBOX type with MULTI_SELECT inputType.
/// Inherits from  `FieldCollector` and is used to collect multiple values from a list of options.
open class MultiSelectCollector: FieldCollector<[String]>, @unchecked Sendable {
    /// A list of available `Option`s. Only writable inside this class.
    public private(set) var options: [Option] = []
    /// The currently selected values for this field.
    public var value: [String] = []
    
    /// Initializes the `MultiSelectCollector` with the given input.
    /// - Parameter json: The json to initialize from.
    public required init(with json: [String : Any]) {
        super.init(with: json)
        
        options = Option.parseOptions(from: json)
    }
    
    /// Initializes the `MultiSelectCollector` with the given value.
    /// - Parameter input: The value to initialize the collector with.
    public override func initialize(with value: Any) {
        if let arrayValue = value as? [String], !arrayValue.isEmpty {
            self.value.append(contentsOf: arrayValue)
        }
    }
    
    /// Validates this collector, returning a list of validation errors if any.
    /// - Returns: An array of `ValidationError`.
    open override func validate() -> [ValidationError] {
        var errors = [ValidationError]()
        
        // If required is true but nothing is selected, add a 'required' error.
        if required && value.isEmpty {
            errors.append(.required)
        }
        
        return errors
    }
    
    override open func payload() -> [String]? {
        return value.isEmpty ? nil : value
    }
}
