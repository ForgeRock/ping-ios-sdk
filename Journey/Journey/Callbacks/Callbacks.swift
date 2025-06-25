//
//  Callbacks.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

/// Callback protocol for actions that can be used in a journey.
/// It conforms to `Action`, `Identifiable`, and `Sendable` protocols.
/// It defines an associated type `T` and requires an initializer that takes a JSON dictionary.
/// It also requires a method to return the payload as a dictionary.
/// The `id` property is used to uniquely identify the callback.
public protocol Callback<T>: Action, Identifiable, Sendable {
    associatedtype T
    init(with json: [String: Any])
    var id: String { get }
    func payload() -> [String: Any]
}

///  Type alias for a list of collectors.
public typealias Callbacks = [any Callback]

extension ContinueNode {
    /// Returns the list of collectors from the actions.
    public var callbacks: [any Callback] {
        return actions.compactMap { $0 as? (any Callback) }
    }
}

/// A class representing a Journey Continue Node.
/// It inherits from `ContinueNode` and conforms to `Sendable`.
/// It is used to continue a journey by sending a request with the provided actions.
final class JourneyContinueNode: ContinueNode, @unchecked Sendable {
    /// The key used for the authentication ID in the request payload.
    private let authIdKey = JourneyConstants.authId
    /// A list of callbacks that will be executed in this journey step.
    private let callbacksList: [any Callback]
    /// The original JSON input that was used to initialize this node.
    private let originalJson: [String: Any]

    /// Initializes a new instance of `JourneyContinueNode`.
    /// - Parameters:
    /// - context: The flow context for the journey.
    /// - workflow: The workflow associated with the journey.
    /// - input: The input data for the journey, which includes the authentication ID.
    /// - actions: The list of callbacks to be executed in this journey step.
    init(context: FlowContext, workflow: Workflow, input: [String: Any], actions: [any Callback]) {
        self.callbacksList = actions
        self.originalJson = input
        super.init(context: context, workflow: workflow, input: input, actions: actions)
    }

    /// Builds the request payload as a dictionary
    private func asJson() -> [String: Any] {
        var result: [String: Any] = [:]
        result[authIdKey] = originalJson[authIdKey] as? String ?? ""

        let payloads: [[String: Any]] = callbacksList
            .map { $0.payload() }
            .filter { !$0.isEmpty }

        result[JourneyConstants.callbacks] = payloads
        return result
    }

    /// Converts to Request
    override func asRequest() -> Request {
        let config = workflow.config as? JourneyConfig
        let realm = config?.realm ?? "root"
        let baseURL = config?.serverUrl ?? ""

        let request = Request()
        request.url("\(baseURL)/json/realms/\(realm)/authenticate")
        request.header(name: JourneyConstants.contentType,  value: JourneyConstants.applicationJson)
        request.body(body: asJson())

        return request
    }
}
