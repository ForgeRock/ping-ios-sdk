//
//  FlowCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate
import Foundation

/// Protocol representing a Collector.
public protocol Collector: Action, Identifiable {
    var id: UUID { get }
    init(with json: [String: Any])
}


extension ContinueNode {
    /// Returns the list of collectors from the actions.
    public var collectors: [any Collector] {
        return actions.compactMap { $0 as? (any Collector) }
    }
}

///  Type alias for a list of collectors.
public typealias Collectors = [any Collector]


extension Collectors {
    /// Finds the event type from a list of collectors.
    ///This function iterates over the list of collectors and returns the value if the collector's value is not empty.
    /// - Returns:  The event type as a String if found, otherwise nil.
    func eventType() -> String? {
        for collector in self {
            if let submitCollector = collector as? SubmitCollector, !submitCollector.value.isEmpty {
                return submitCollector.value
            }
            if let flowCollector = collector as? FlowCollector, !flowCollector.value.isEmpty {
                return flowCollector.value
            }
        }
        return nil
    }
    
    /// Represents a list of collectors as a JSON object for posting to the server.
    /// This function takes a list of collectors and represents it as a JSON object. It iterates over the list of collectors,
    /// adding each collector's key and value to the JSON object if the collector's value is not empty.
    /// - Returns: JSON object representing the list of collectors.
    func asJson() -> [String: Any] {
        var jsonObject: [String: Any] = [:]
        
        for collector in self {
            if let submitCollector = collector as? SubmitCollector, !submitCollector.value.isEmpty {
                jsonObject[Constants.actionKey] = submitCollector.key
            }
            if let flowCollector = collector as? FlowCollector, !flowCollector.value.isEmpty {
                jsonObject[Constants.actionKey] = flowCollector.key
            }
        }
        
        var formData: [String: Any] = [:]
        for collector in self {
            if let textCollector = collector as? TextCollector, !textCollector.value.isEmpty {
                //TODO: Revert this when the nested key is removed.
                //formData[textCollector.key] = textCollector.value
                toMap(map: &formData, key: textCollector.key, value: textCollector.value)
            }
            if let passwordCollector = collector as? PasswordCollector, !passwordCollector.value.isEmpty {
                //TODO: Revert this when the nested key is removed.
                //formData[passwordCollector.key] = passwordCollector.value
                toMap(map: &formData, key: passwordCollector.key, value: passwordCollector.value)
            }
            if let singleSelectCollector = collector as? SingleSelectCollector, !singleSelectCollector.value.isEmpty {
                //TODO: Revert this when the nested key is removed.
                //formData[singleSelectCollector.key] = singleSelectCollector.value
                toMap(map: &formData, key: singleSelectCollector.key, value: singleSelectCollector.value)
            }
            if let multiSelectCollector = collector as? MultiSelectCollector, !multiSelectCollector.value.isEmpty {
                //TODO: Revert this when the nested key is removed.
                //formData[multiSelectCollector.key] = multiSelectCollector.value
                toMap(map: &formData, key: multiSelectCollector.key, value: multiSelectCollector.value)
            }
        }
        
        //TODO: Revert this when the nested key is removed.
        // jsonObject[Constants.formData] = formData
        jsonObject[Constants.formData] = Helper.mapToJsonObject(map: formData)
        return jsonObject
    }
    
    //TODO: Remove this when the nested key is removed.
    private func toMap(map: inout [String: Any], key: String, value: Any) {
        let parts = key.components(separatedBy: ".")
        Helper.setNestedValue(&map, parts: parts, value: value)
    }
        
}

//TODO: Remove this when the nested key is removed.
struct Helper {
    //TODO: Remove this when the nested key is removed.
    static func setNestedValue(_ map: inout [String: Any],
                                parts: [String],
                                value: Any) {
        guard !parts.isEmpty else { return }
        
        let head = parts[0]
        let x = parts.dropFirst()
        let tail = Array(x)
        if tail.isEmpty {
            // We've reached the final key—set the value
            map[head] = value
        } else {
            // If the sub-dictionary at `head` does not exist or is not a dictionary, create a new one
            if map[head] == nil || !(map[head] is [String: Any]) {
                map[head] = [String: Any]()
            }
            
            // Descend into the nested dictionary
            var child = map[head] as! [String: Any]
            setNestedValue(&child, parts: tail, value: value)
            
            // Write the updated child back
            map[head] = child
        }
    }
    
    //TODO: Remove this when the nested key is removed.
    static func mapToJsonObject(map: [String: Any]) -> [String: Any] {
        var jsonObject: [String: Any] = [:]
        
        for (key, value) in map {
            switch value {
            case let nestedMap as [String: Any]:
                jsonObject[key] = mapToJsonObject(map: nestedMap)
                
            case let array as [Any]:
                jsonObject[key] = array.map { String(describing: $0) }
                
            case let string as String:
                jsonObject[key] = string
                
            case let bool as Bool:
                jsonObject[key] = bool
                
            case let number as NSNumber:
                jsonObject[key] = number
                
            default:
                jsonObject[key] = String(describing: value)
            }
        }
        
        return jsonObject
    }
}
