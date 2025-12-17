//
//  Collector.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate
import Foundation

/// Protocol representing a collector. Inherits from `Sendable`, `Collector`, `Validator`.
/// - property id: The collector id.
/// - function anyPayload: The payload of the collector as `Any`
/// - function initialize: Initializes the collector with the given value.
public protocol AnyFieldCollector: Collector, Validator, Sendable {
    var id: String { get }
    /// Returns the payload as `Any?`.
    func anyPayload() -> Any?
    /// Initializes the field collector with the given value.
    func initialize(with value: Any)
}

/// Protocol representing a Collector.
/// It is a generic protocol that defines the structure for creating different types of collectors.
/// It inherits from the Action protocol and conforms to Identifiable and Sendable protocols.
/// - Parameters:
///   - T: The type of the payload that the collector will handle.
///   - id: A unique identifier for the collector.
///   - init(with json: [String: Any]): Initializes the collector with a JSON object.
///   - payload(): Returns the payload of type T. When payload returns nil, the field will not be posted to server.
public protocol Collector<T>: Action, Identifiable, Sendable {
    associatedtype T
    var id: String { get }
    init(with json: [String: Any]) 
    func initialize(with value: Any)
    func payload() -> T?
}

extension Collector {
    /// Default implementation of the payload method.
    func payload() -> T? {
        return nil
    }
}
