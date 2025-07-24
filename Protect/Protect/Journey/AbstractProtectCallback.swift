//
//  AbstractProtectCallback.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingJourney

/// Abstract Protect Callback that provides the raw content of the Callback, and common methods
/// for sub classes to access.
open class AbstractProtectCallback: AbstractCallback, ContinueNodeAware, @unchecked Sendable {

    /// Reference to the continue node for accessing other callbacks
    public weak var continueNode: ContinueNode?
    private var derivedCallback: Bool = false
    
    /// Initializes a new instance of `AbstractProtectCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        // Handle derived callback logic if needed
        // This would be implemented based on specific Swift JSON structure
    }
    
    /// Initialize from JSON object
    public override func initialize(with json: [String: Any]) -> any Callback {
        if let type = json[JourneyConstants.type] as? String, type == JourneyConstants.metadataCallback {
            derivedCallback = true
            if let output = json[JourneyConstants.output] as? [[String: Any]],
               let firstOutput = output.first,
               let name = firstOutput[JourneyConstants.name] as? String,
               name == JourneyConstants.data,
               let value = firstOutput[JourneyConstants.value] as? [String: Any] {
                for (key, val) in value {
                    initValue(name: key, value: val)
                }
            }
            return self
        } else {
            // Use standard initialization
            return super.initialize(with: json)
        }
    }
    
    /// Input the Client Error to the server
    /// - Parameter value: Protect ErrorType
    public func error(_ value: String) {
        if derivedCallback {
            valueCallbackError(value)
        } else {
            _ = input(value)
        }
    }
    
    /// Input the Signal to the server
    /// - Parameters:
    ///   - value: The JWS value
    ///   - error: Error message if any
    public func signal(_ value: String, error: String) {
        if derivedCallback {
            if !value.isEmpty {
                valueCallbackSignal(value)
            }
            if !error.isEmpty {
                valueCallbackError(error)
            }
        } else {
            _ = input(value, error)
        }
    }
    
    /// Set the signals to the HiddenValueCallback which associated with the callback
    /// - Parameter value: The Value to set to the HiddenValueCallback
    private func valueCallbackSignal(_ value: String) {
        guard let continueNode = continueNode else { return }
        
        for callback in continueNode.callbacks {
            if let valueCallback = callback as? HiddenValueCallback,
               valueCallback.hiddenId.contains(JourneyConstants.pingone_risk_evaluation_signals) {
                valueCallback.value = value
            }
        }
    }
    
    /// Set the client error to the HiddenValueCallback which associated with the Protect Callback
    /// - Parameter value: The Value to set to the HiddenValueCallback
    private func valueCallbackError(_ value: String) {
        guard let continueNode = continueNode else { return }
        
        for callback in continueNode.callbacks {
            if let valueCallback = callback as? HiddenValueCallback,
               valueCallback.hiddenId.contains(JourneyConstants.clientError) {
                valueCallback.value = value
            }
        }
    }
}

extension JourneyConstants {
    public static let clientError = "clientError"
    public static let pingone_risk_evaluation_signals = "pingone_risk_evaluation_signals"
}
