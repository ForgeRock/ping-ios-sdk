// 
//  SubmitCollectorProtocol.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A protocol describing the minimal interface required for a submit-type collector.
/// Submit collectors typically represent buttons or actions that trigger
/// progression of a form or flow.
///
/// Conforming types should provide an identifier, a current value (e.g., button label),
/// and an event type to be emitted when submitting.
public protocol SubmitCollectorProtocol {
    /// The current value associated with the submit control (e.g., button label).
    var value: String { get }
    /// The unique identifier of this collector instance (as provided by the server).
    var id: String { get }
    /// The event type string to be sent to the server when this collector is submitted.
    func eventType() -> String
}

