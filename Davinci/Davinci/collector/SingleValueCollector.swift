// 
//  SingleValueCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// A class representing a single value collector,
/// Inheriting from `FieldCollector` and conforming to `Collector`.
open class SingleValueCollector: FieldCollector {
    /// The single value to collect.
    public var value: String = ""

    /// Initializes the single value collector with the given input.
    /// - Parameter json: A dictionary representing the JSON element to parse.
    public required init(with json: [String: Any]) {
        // Call the parent’s initialization
        super.init(with: json)
        
        // Extract the value from the input dictionary
        if let stringValue = json[Constants.value] as? String {
            value = stringValue
        }
    }
    
    /// Initializes the `SingleValueCollector` with the given value.
    /// - Parameter value: The value to initialize the collector with.
    public override func initialize(with value: Any) {
        if let stringValue = value as? String {
            self.value = stringValue
        }
    }
}
