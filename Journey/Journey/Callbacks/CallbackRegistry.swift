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

/// A protocol that defines a type for JourneyAware.
/// Exposes the journey property that can be set.
/// This protocol is used to inject the Journey instance into Callbacks that need it.
/// - Parameters:
///  - journey: The Journey instance that the Callback is aware of.
public protocol JourneyAware {
    var journey: Journey? { get set }
}

/// A registry for managing Callback instances.
/// It holds a dictionary of registered Callback types and provides methods to create and manage them.
/// It is a singleton class that can be accessed globally.
/// It allows for the registration of default Callbacks and the creation of Callback instances from a list of dictionaries.
/// It also provides a method to inject a `ContinueNode` into the Callbacks, allowing them to be aware of the Journey they are part of.
/// The `CallbackRegistry` is an actor to ensure thread safety when accessing and modifying the callbacks dictionary.
/// - Parameters:
/// - callbacks: A dictionary that maps Callback type names to their respective Callback classes.
/// - Methods:
///  - registerDefaultCallbacks: Registers the default Journey Callbacks.
///  - register(type:callback:): Registers a new type of Callback.
///  - callback(from:): Creates a list of Callback instances from an array of dictionaries.
///  - inject(continueNode:): Injects the ContinueNode instances into the collectors.
///  - reset: Resets the CallbackRegistry by clearing all registered callbacks.
public actor CallbackRegistry: @unchecked Sendable {
    /// A dictionary to hold the collector creation functions.
    var callbacks: [String: any Callback.Type] = [:]
    
    /// The shared instance of the CallbackRegistry.
    public static let shared = CallbackRegistry()
    
    init() { }
    
    /// Registers the default Journey Callbacks.
    public func registerDefaultCallbacks() {
        register(type: JourneyConstants.nameCallback, callback: NameCallback.self)
        register(type: JourneyConstants.passwordCallback, callback: PasswordCallback.self)
    }
    
    /// Registers a new type of Callback.
    /// - Parameters:
    ///   - type: The type of the Callback.
    ///   - block: A function that creates a new instance of the Callback.
    public func register(type: String, callback: any Callback.Type) {
        callbacks[type] = callback
    }
    
    /// Creates a list of Callback instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Callback type.
    /// - Parameter array: The array of dictionaries to create the Callbacks from.
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
    
    /// Resets the CallbackRegistry by clearing all registered collectors.
    public func reset() {
        callbacks.removeAll()
    }
}
