//
//  CallbackRegistry.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights.
//
 //  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// A registry for managing Callback instances.
/// It holds a dictionary of registered Callback types and provides methods to create and manage them.
/// It is a singleton actor that can be accessed globally.
/// It allows for the registration of default Callbacks and the creation of Callback instances from a list of dictionaries.
/// It also provides a method to inject a `ContinueNode` into the Callbacks, allowing them to be aware of the Journey they are part of.
public actor CallbackRegistry {
    /// Internal storage for callback types
    private var callbacksStorage: [String: any Callback.Type] = [:]

    /// Thread-safe read-only access to the callbacks dictionary
    public var callbacks: [String: any Callback.Type] {
        callbacksStorage
    }

    /// The shared instance of the CallbackRegistry.
    public static let shared = CallbackRegistry()

    /// Initializes a new CallbackRegistry.
    /// Prefer using `CallbackRegistry.shared` unless test isolation is required.
    init() { }

    /// Registers a new type of Callback.
    /// - Parameters:
    ///   - type: The type of the Callback.
    ///   - callback: The concrete Callback metatype to register.
    public func register(type: String, callback: any Callback.Type) {
        callbacksStorage[type] = callback
    }

    /// Creates a list of Callback instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Callback type.
    /// - Parameter array: The array of dictionaries to create the Callbacks from.
    /// - Returns: A list of Callback instances (metadata callbacks are filtered out).
    public func callback(from array: [[String: any Sendable]]) async -> Callbacks {
        var list = Callbacks()
        for item in array {
            guard let typeKey = item[JourneyConstants.type] as? String,
                  let registeredType = callbacksStorage[typeKey] else {
                continue
            }

            // Instantiate the registered type. If it's a MetadataCallback, it may specialize itself
            // in its initialize(with:) implementation and return a different concrete instance.
            let produced = await registeredType.init().initialize(with: item)

            // Filter out metadata-only callbacks from the returned list
            if !(produced is MetadataCallbackProtocol) {
                list.append(produced)
            }
        }
        return list
    }

    /// Injects the ContinueNode and Journey instances into the callbacks that require them.
    /// - Parameters:
    ///   - continueNode: The ContinueNode instance to be injected.
    ///   - journey: The Journey workflow instance to be injected.
    public func inject(continueNode: ContinueNode, journey: Journey) {
        continueNode.callbacks.forEach { callback in
            if var callback = callback as? JourneyAware {
                callback.journey = journey
            }
            if var callback = callback as? ContinueNodeAware {
                callback.continueNode = continueNode
            }
        }
    }

    /// Resets the CallbackRegistry by clearing all registered callbacks.
    public func reset() {
        callbacksStorage.removeAll()
    }

    /// Accessor for a registered metatype by key, used by MetadataCallback specialization.
    /// - Parameters:
    ///   - key: String
    /// - Returns: A Callback type
    public func type(for key: String) -> (any Callback.Type)? {
        callbacksStorage[key]
    }
}

