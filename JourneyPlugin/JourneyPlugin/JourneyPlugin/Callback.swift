//
//  Callbacks.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

/// Base protocol for Journey callbacks used as actions in a Journey step.
///
/// Conforms to `Action`, `Identifiable`, and `Sendable`.
/// Each callback must be default-initializable and able to initialize itself from a JSON dictionary.
/// The `payload()` method returns a serializable representation of the callback to send back to the server.
public protocol Callback: Action, Identifiable, Sendable {
    /// Required default initializer.
    init()
    /// Initializes this callback from a server-provided JSON dictionary and returns `self` (synchronous variant).
    /// - Parameter json: The raw JSON dictionary describing this callback instance.
    func initialize(with json: [String: Any]) -> any Callback
    /// Initializes this callback from a server-provided JSON dictionary and returns `self` (async variant).
    /// - Parameter json: The raw JSON dictionary describing this callback instance.
    func initialize(with json: [String: Any]) async -> any Callback
    /// The unique identifier for this callback instance.
    var id: String { get }
    /// A dictionary payload representing this callback's data for submission.
    func payload() -> [String: Any]
}

/// Default implementation for the async initializer that forwards to the synchronous variant.
/// Conformers that only implement the synchronous initializer will automatically satisfy the async requirement.
/// Conformers can override this async implementation when they need to perform asynchronous work.
public extension Callback {
    func initialize(with json: [String: Any]) async -> any Callback {
        return await initialize(with: json)
    }
    
    func initialize(with json: [String: Any]) -> any Callback {
        return initialize(with: json)
    }
}

/// Marker protocol indicating a callback is metadata-only and should not be included in submission payloads.
public protocol MetadataCallbackProtocol { }

/// Protocol for hidden value callbacks that carry an ID and a value to be returned.
///
/// Conforming callbacks expose a hidden identifier, a value to submit, and a convenience setter.
public protocol ValueCallbackProtocol {
    /// Hidden identifier value.
    var valueId: String { get set }
    /// The hidden value to be sent back.
    var value: String { get }
    /// Convenience method to update the hidden value.
    func setValue(_ value: String)
}

/// Type alias for a list of callbacks in a Journey step.
public typealias Callbacks = [any Callback]
