//
//  CallbackRegistry.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

public protocol JourneyAware {
    var journey: Journey? { get set }
}

public actor CallbackRegistry: @unchecked Sendable {
    /// A dictionary to hold the collector creation functions.
    var callbacks: [String: any Callback.Type] = [:]
    
    /// The shared instance of the CollectorFactory.
    public static let shared = CallbackRegistry()
    
    init() { }
    
    /// Registers the default DaVinci Collectors.
    public func registerDefaultCallbacks() {
        register(type: JourneyConstants.nameCallback, callback: NameCallback.self)
        register(type: JourneyConstants.passwordCallback, callback: PasswordCallback.self)
    }
    
    /// Registers a new type of Collector.
    /// - Parameters:
    ///   - type: The type of the Collector.
    ///   - block: A function that creates a new instance of the Collector.
    public func register(type: String, callback: any Callback.Type) {
        callbacks[type] = callback
    }
    
    /// Creates a list of Collector instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Collector type.
    /// - Parameter array: The array of dictionaries to create the Collectors from.
    /// - Returns: A list of Collector instances.
    public func callback(from array: [[String: Any]]) -> Callbacks {
        var list = Callbacks()
        for item in array {
            if let type = item[JourneyConstants.type] as? String, let callbackType = callbacks[type] {
                list.append(callbackType.init(with: item))
            }
        }
        return list
    }
    
    /// Injects the ContinueNode instances into the collectors.
    /// - Parameter continueNode: The ContinueNode instance to be injected.
    public func inject(continueNode: ContinueNode, journey: Journey) {
        continueNode.callbacks.forEach { callback in
            if var callback = callback as? JourneyAware {
                callback.journey = journey
            }
        }
    }
    
    /// Resets the CollectorFactory by clearing all registered collectors.
    public func reset() {
        callbacks.removeAll()
    }
}
