//
// CallbackPlugin.swift
//
// PingJourneyPlugin
//
// Copyright (c) 2024 Ping Identity. All rights reserved.
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol that all Journey callbacks must conform to.
///
/// Callbacks represent interactive elements in a Journey flow that collect
/// user input or perform specific actions. Each callback has a type identifier
/// and can hold input values.
public protocol CallbackPlugin {
    /// The type identifier for this callback (e.g., "NameCallback", "PasswordCallback")
    var type: String { get }
    
    /// The input value provided by the user or plugin
    var inputValue: Any? { get set }
    
    /// Optional output values returned by the callback
    var outputValue: [String: Any]? { get }
}

/// Protocol for registering callback handlers with the Journey system.
///
/// Plugins implement this protocol to register custom callback handlers that can
/// process and respond to specific callback types during Journey flows.
public protocol CallbackPluginRegistry {
    /// Registers a callback handler for a specific callback type.
    ///
    /// - Parameters:
    ///   - callbackType: The type identifier of the callback to handle
    ///   - handler: A closure that creates a CallbackPlugin instance from raw data
    func register(callbackType: String, handler: @escaping (Any) -> CallbackPlugin?)
    
    /// Unregisters a callback handler for a specific callback type.
    ///
    /// - Parameter callbackType: The type identifier of the callback handler to remove
    func unregister(callbackType: String)
}

/// Protocol for Journey nodes that contain callbacks.
///
/// A Journey node represents a step in the authentication or authorization flow
/// that may contain one or more callbacks requiring user interaction or plugin processing.
public protocol JourneyNodePlugin {
    /// The collection of callbacks in this node
    var callbacks: [CallbackPlugin] { get }
    
    /// The stage identifier for this node
    var stage: String? { get }
    
    /// Proceeds to the next node in the Journey flow.
    ///
    /// - Returns: The next Journey node, or nil if the flow is complete
    /// - Throws: An error if the flow cannot proceed
    func next() async throws -> JourneyNodePlugin?
}

/// Protocol for Journey flow execution.
///
/// The Journey flow manages the overall authentication or authorization process,
/// coordinating between nodes and managing the callback plugin registry.
public protocol JourneyFlowPlugin {
    /// The callback plugin registry for this flow
    var callbackRegistry: CallbackPluginRegistry { get }
    
    /// Starts the Journey flow.
    ///
    /// - Returns: The first Journey node
    /// - Throws: An error if the flow cannot be started
    func start() async throws -> JourneyNodePlugin
}

/// Protocol for Journey result handling.
///
/// Represents the final result of a completed Journey flow, which may contain
/// tokens, user information, or other flow-specific data.
public protocol JourneyResultPlugin {
    /// The success status of the Journey
    var success: Bool { get }
    
    /// The result data from the completed Journey
    var data: [String: Any] { get }
    
    /// Optional error information if the Journey failed
    var error: Error? { get }
}
