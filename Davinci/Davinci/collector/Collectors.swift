// 
//  Collectors.swift
//  PingDavinci
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
    /// Returns the event type from the first `SubmitCollector` or `FlowCollector` whose `actionKey`
    /// is non-nil (i.e. the user has selected that button), then falls back to the first `Submittable`
    /// whose `payload()` is non-nil (e.g. a failed FIDO collector reporting a WebAuthn error).
    /// Submit/Flow collectors take precedence so a concurrently-failed FIDO collector cannot shadow
    /// an explicit user action in the same node.
    /// - Returns: The event type as a String if found, otherwise nil.
    public func eventType() -> String? {
        // First pass: honour explicit Submit/Flow actions.
        for collector in self {
            switch collector {
            case let collector as SubmitCollector where collector.actionKey != nil:
                return collector.eventType()
            case let collector as FlowCollector where collector.actionKey != nil:
                return collector.eventType()
            default:
                break
            }
        }
        // Second pass: fall back to ActionKeyProvider-based event types (e.g. FIDO errors).
        for collector in self {
            if let submittable = collector as? any Submittable, collector.payload() != nil {
                return submittable.eventType()
            }
        }
        return nil
    }
    
    /// Represents a list of collectors as a JSON object for posting to the server.
    /// This function takes a list of collectors and represents it as a JSON object. It iterates over the list of collectors,
    /// adding each collector's key and value to the JSON object if the collector's value is not empty.
    /// `SubmitCollector`, `FlowCollector`, and `MetadataCollector` always take precedence for `actionKey`;
    /// any other `ActionKeyProvider` (e.g. a failed FIDO collector) only sets `actionKey` when it has not
    /// already been set.
    /// - Returns: JSON object representing the list of collectors.
    public func asJson() -> [String: Any] {
        var jsonObject: [String: Any] = [:]
        var formData: [String: Any] = [:]
        for collector in self {
            switch collector {
            case let collector as (any ActionKeyProvider) where collector is SubmitCollector || collector is FlowCollector:
                if let key = collector.actionKey {
                    jsonObject[Constants.actionKey] = key
                }
            case let collector as MetadataCollector:
                if let key = collector.actionKey, let payload = collector.anyPayload() {
                    jsonObject[Constants.actionKey] = key
                    formData[key] = payload
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
