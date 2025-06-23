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

final class JourneyContinueNode: ContinueNode, @unchecked Sendable {
    private let authIdKey = JourneyConstants.authId
    private let callbacksList: [any Callback]
    private let originalJson: [String: Any]

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
