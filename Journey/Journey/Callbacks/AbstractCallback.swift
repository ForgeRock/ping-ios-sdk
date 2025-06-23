//
//  AbstractCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

open class AbstractCallback<T>: Callback, @unchecked Sendable {
    
    public var json: [String: Any] = [:]
    
    public required init(with json: [String: Any]) {
        self.json = json
        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                if let name = item["name"] as? String,
                   let value = item["value"], !(value is NSNull) {
                    initValue(name: name, value: value)
                }
            }
        }
    }

    /// Abstract method – must be implemented by subclass
    open func initValue(name: String, value: Any) {
        fatalError("Subclasses must override initValue(name:value:)")
    }

    /// Generates an updated payload with input values inserted
    public func input(_ values: Any...) -> [String: Any] {
        guard let inputArray = json["input"] as? [[String: Any]] else {
            return json
        }

        var updatedInput: [[String: Any]] = []

        for (index, value) in values.enumerated() {
            let name = (index < inputArray.count) ? (inputArray[index]["name"] as? String ?? "") : ""

            var entry: [String: Any] = ["name": name]
            if value is Int || value is String || value is Bool || value is Double {
                entry["value"] = value
            }
            updatedInput.append(entry)
        }

        json["input"] = updatedInput
        return json
    }

    /// Returns the full JSON payload
    public func payload() -> [String: Any] {
        return json
    }

    // MARK: - Required Protocol Stubs

    public var id: String {
        return UUID().uuidString // Replace with a real identifier if needed
    }

    public init() {} // Required for registry factory
}
