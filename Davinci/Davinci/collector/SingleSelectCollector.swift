// 
//  SingleSelectCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A class representing a DROPDOWN or RADIO type with SINGLE_SELECT inputType.
/// Inherits from `ValidatedCollector` and is used to collect multiple values from a list of options.
public class SingleSelectCollector: ValidatedCollector, @unchecked Sendable {
    /// Holds a list of `Option` objects. The setter is private, so it can only be assigned within this class.
    public private(set) var options: [Option] = []
    
    /// Initializes the `SingleSelectCollector` with the given input.
    /// - Parameter json: A dictionary representing the JSON object to parse.
    public required init(with json: [String : Any]) {
        super.init(with: json)
        
        options = Option.parseOptions(from: json)
    }
}
