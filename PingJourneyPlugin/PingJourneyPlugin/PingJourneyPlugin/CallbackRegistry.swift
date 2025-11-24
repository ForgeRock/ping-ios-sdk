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
    public func callback(from array: [[String: Any]]) -> Callbacks {
        var list = Callbacks()
        for item in array {
            guard let typeKey = item[JourneyConstants.type] as? String,
                  let registeredType = callbacksStorage[typeKey] else {
                continue
            }

            // If this is a MetadataCallback, attempt to specialize synchronously
            let concreteType: any Callback.Type
            if registeredType is MetadataCallbackProtocol.Type,
               let specialized = specializedType(for: item) {
                concreteType = specialized
            } else {
                concreteType = registeredType
            }

            let callback = concreteType.init().initialize(with: item)
            if !(callback is MetadataCallbackProtocol) {
                list.append(callback)
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
}

// MARK: - Specialization helpers (internal to actor)
extension CallbackRegistry {
    /// Attempt to resolve a specialized callback type for a metadata item.
    /// - Parameter item: Raw JSON dictionary describing the callback.
    /// - Returns: A registered Callback.Type if a specialization is applicable; otherwise nil.
    private func specializedType(for item: [String: Any]) -> (any Callback.Type)? {
        // Extract metadata value from output[data]
        guard let output = item[JourneyConstants.output] as? [[String: Any]],
              let dataEntry = output.first(where: { ($0[JourneyConstants.name] as? String) == JourneyConstants.data }),
              let value = dataEntry[JourneyConstants.value] as? [String: Any] else {
            return nil
        }

        // Decide specialization
        if isProtectInitialize(value: value),
           let t = callbacksStorage[SpecializationConstants.pingOneProtectInitialize] {
            return t
        }
        if isProtectEvaluation(value: value),
           let t = callbacksStorage[SpecializationConstants.pingOneProtectEvaluation] {
            return t
        }
        if isFidoRegistration(value: value),
           let t = callbacksStorage[SpecializationConstants.fidoRegistration] {
            return t
        }
        if isFidoAuthentication(value: value),
           let t = callbacksStorage[SpecializationConstants.fidoAuthentication] {
            return t
        }
        return nil
    }

    private func isFidoRegistration(value: [String: Any]) -> Bool {
        if let action = value[SpecializationConstants.action] as? String,
           action == SpecializationConstants.webauthnRegistration {
            return true
        }
        if let type = value[SpecializationConstants.type] as? String,
           type == SpecializationConstants.webAuthn {
            return value.keys.contains(SpecializationConstants.pubKeyCredParams)
                || value.keys.contains(SpecializationConstants._pubKeyCredParams)
        }
        return false
    }

    private func isFidoAuthentication(value: [String: Any]) -> Bool {
        if let action = value[SpecializationConstants.action] as? String,
           action == SpecializationConstants.webauthnAuthentication {
            return true
        }
        if let type = value[SpecializationConstants.type] as? String,
           type == SpecializationConstants.webAuthn {
            return value.keys.contains(SpecializationConstants.allowCredentials)
                || value.keys.contains(SpecializationConstants._allowCredentials)
        }
        return false
    }

    private func isProtectInitialize(value: [String: Any]) -> Bool {
        guard let type = value[SpecializationConstants.type] as? String,
              type == SpecializationConstants.pingOneProtect,
              let action = value[SpecializationConstants.action] as? String,
              action == SpecializationConstants.protectInitialize else {
            return false
        }
        return true
    }

    private func isProtectEvaluation(value: [String: Any]) -> Bool {
        guard let type = value[SpecializationConstants.type] as? String,
              type == SpecializationConstants.pingOneProtect,
              let action = value[SpecializationConstants.action] as? String,
              action == SpecializationConstants.protectRiskEvaluation else {
            return false
        }
        return true
    }
}

private enum SpecializationConstants {
    // Registry keys for specialized callbacks
    static let pingOneProtectInitialize = "PingOneProtectInitializeCallback"
    static let pingOneProtectEvaluation = "PingOneProtectEvaluationCallback"
    static let fidoRegistration = "FidoRegistrationCallback"
    static let fidoAuthentication = "FidoAuthenticationCallback"

    // Metadata keys/values
    static let action = "_action"
    static let type = "_type"
    static let webAuthn = "WebAuthn"
    static let webauthnRegistration = "webauthn_registration"
    static let webauthnAuthentication = "webauthn_authentication"
    static let _pubKeyCredParams = "_pubKeyCredParams"
    static let pubKeyCredParams = "pubKeyCredParams"
    static let pingOneProtect = "PingOneProtect"
    static let protectInitialize = "protect_initialize"
    static let protectRiskEvaluation = "protect_risk_evaluation"
    static let allowCredentials = "allowCredentials"
    static let _allowCredentials = "_allowCredentials"
}

