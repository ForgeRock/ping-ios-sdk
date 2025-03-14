// 
//  Option.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A struct representing an option.
/// - Parameters:
///   - label: The label of the option.
///   - value: The value of the option.
public struct Option: Sendable {
    public let label: String
    public let value: String
    
    /// Initializes an `Option` struct with the given label and value.
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    /// Parses the input dictionary to return a list of options.
    /// - Parameter input: A dictionary simulating the JSON object.
    /// - Returns: An array of `Option` structs.
    public static func parseOptions(from input: [String: Any]) -> [Option] {
        // Expect "options" to be an array of dictionaries, each describing an option.
        guard let rawOptions = input[Constants.options] as? [[String: Any]] else {
            return []
        }
        
        return rawOptions.map { dict in
            let label = dict[Constants.label] as? String ?? ""
            let value = dict[Constants.value] as? String ?? ""
            return Option(label: label, value: value)
        }
    }
}
