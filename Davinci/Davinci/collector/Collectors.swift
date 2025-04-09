// 
//  Collectors.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate
import Foundation

///  Type alias for a list of collectors.
public typealias Collectors = [any Collector]

extension Collectors {
    /// Finds the event type from a list of collectors.
    /// This function iterates over the list of collectors and returns the value if the collector's value is not empty.
    /// - Returns: The event type as a String if found, otherwise nil.
    func eventType() -> String? {
        for collector in self {
            if let submittable = collector as? Submittable {
                if collector.payload() != nil {
                    return submittable.eventType()
                }
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
        var formData: [String: Any] = [:]
        for collector in self {
            switch collector {
            case let collector as SubmitCollector:
                if collector.value.isEmpty == false {
                    jsonObject[Constants.actionKey] = collector.id
                }
            case let collector as FlowCollector:
                if collector.value.isEmpty == false {
                    jsonObject[Constants.actionKey] = collector.id
                }
            default:
                if let fieldCollector = collector as? (any AnyFieldCollector), let payload = fieldCollector.anyPayload() {
                    formData[fieldCollector.id] = payload
                }
            }
        }
        
        jsonObject[Constants.formData] = formData
        return jsonObject
    }
        
}

extension ContinueNode {
    /// Returns the list of collectors from the actions.
    public var collectors: [any Collector] {
        return actions.compactMap { $0 as? (any Collector) }
    }
}
