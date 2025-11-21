//
//  AbstractCallback.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A base class for callbacks that provides a JSON payload and methods to manipulate input values.
/// This class is designed to be subclassed for specific callback implementations.
open class AbstractCallback: Callback, @unchecked Sendable {
    /// The JSON payload for the callback, containing input and output data.
    public var json: [String: Any] = [:]

    /// Initializes a new instance of `AbstractCallback` with the provided JSON.
    open func initialize(with json: [String: Any]) -> any Callback {
        self.json = json
        if let output = json[JourneyConstants.output] as? [[String: Any]] {
            for item in output {
                if let name = item[JourneyConstants.name] as? String,
                   let value = item[JourneyConstants.value], !(value is NSNull) {
                    initValue(name: name, value: value)
                }
            }
        }
        return self
    }

    /// Abstract method – must be implemented by subclass
    open func initValue(name: String, value: Any) {
        fatalError("Subclasses must override initValue(name:value:)")
    }

    /// Generates an updated payload with input values inserted
    public func input(_ values: Any...) -> [String: Any] {
        guard let inputArray = json[JourneyConstants.input] as? [[String: Any]] else {
            return json
        }

        var updatedInput: [[String: Any]] = []

        for (index, value) in values.enumerated() {
            let name = (index < inputArray.count) ? (inputArray[index][JourneyConstants.name] as? String ?? "") : ""

            var entry: [String: Any] = [JourneyConstants.name: name]
            if value is Int || value is String || value is Bool || value is Double {
                entry[JourneyConstants.value] = value
            }
            updatedInput.append(entry)
        }

        json[JourneyConstants.input] = updatedInput
        return json
    }
    
    /// Update input value with specified key
    /// - Parameters:
    ///   - value: Value of the input to be updated
    ///   - key: The name/key of the input to be updated
    /// - Returns: The updated json dictionary
    public func input(_ value: Any, forKey key: String) -> [String: Any] {
        guard var inputArray = json[JourneyConstants.input] as? [[String: Any]] else {
            return json
        }
        
        // Find the index of the input with matching name
        guard let index = inputArray.firstIndex(where: {
            ($0[JourneyConstants.name] as? String) == key
        }) else {
            return json
        }
        
        if value is Int || value is String || value is Bool || value is Double {
            inputArray[index][JourneyConstants.value] = value
        }
        
        json[JourneyConstants.input] = inputArray
        return json
    }

    /// Returns the full JSON payload
    open func payload() -> [String: Any] {
        return json
    }


    // MARK: - Required Protocol Stubs

    /// A unique identifier for the callback instance.
    public var id: String {
        return UUID().uuidString // Replace with a real identifier if needed
    }

    /// Initializer for the callback.
    required public init() {} // Required for registry factory
}
