// 
//  Collectors.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate
import Foundation
import PingDavinciPlugin

///  Type alias for a list of collectors.
public typealias Collectors = [any Collector]

extension Collectors {
    /// Finds the event type from a list of collectors.
    /// This function iterates over the list of collectors and returns the value if the collector's value is not empty.
    /// Submit/Flow collectors take precedence over ActionKeyProvider collectors so a failed FIDO
    /// collector cannot shadow an explicit user action in the same node.
    /// - Returns: The event type as a String if found, otherwise nil.
    public func eventType() -> String? {
        // First pass: honour explicit Submit/Flow actions.
        for collector in self {
            switch collector {
            case let collector as SubmitCollector where !collector.value.isEmpty:
                return collector.eventType()
            case let collector as FlowCollector where !collector.value.isEmpty:
                return collector.eventType()
            default:
                break
            }
        }
        // Second pass: fall back to ActionKeyProvider-based event types (e.g. FIDO errors).
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
    /// `SubmitCollector` and `FlowCollector` always take precedence for `actionKey`; an `ActionKeyProvider`
    /// (e.g. a failed FIDO collector) only sets `actionKey` when it has not already been set.
    /// - Returns: JSON object representing the list of collectors.
    public func asJson() -> [String: Any] {
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
            case let collector as MetadataCollector:
                if let payload = collector.anyPayload() {
                    jsonObject[Constants.actionKey] = collector.id
                    formData[collector.id] = payload
                }
            default:
                if let actionKeyProvider = collector as? any ActionKeyProvider,
                   let key = actionKeyProvider.actionKey,
                   jsonObject[Constants.actionKey] == nil {
                    jsonObject[Constants.actionKey] = key
                } else if let fieldCollector = collector as? (any AnyFieldCollector),
                          let payload = fieldCollector.anyPayload() {
                    formData[fieldCollector.id] = payload
                }
            }
        }
        
        jsonObject[Constants.formData] = formData
        return jsonObject
    }
        
}
