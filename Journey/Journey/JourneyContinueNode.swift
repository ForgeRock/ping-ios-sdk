//
//  JourneyContinueNode.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingJourneyPlugin
import PingOrchestrate

/// A ContinueNode specialized for Journey flows.
///
/// Builds the JSON payload from contained callbacks and constructs the HTTP request
/// targeting the Journey authenticate endpoint.
public final class JourneyContinueNode: ContinueNode, @unchecked Sendable {
    /// The JSON key holding the authentication ID.
    private let authIdKey = JourneyConstants.authId
    /// The list of callbacks that will be executed in this journey step.
    private let callbacksList: [any Callback]
    /// The original JSON input used to initialize this node.
    private let originalJson: [String: Any]

    /// Creates a new JourneyContinueNode.
    ///
    /// - Parameters:
    ///   - context: The flow context for the journey.
    ///   - workflow: The owning workflow instance.
    ///   - input: The raw input JSON for this step (contains authId and callbacks).
    ///   - actions: The list of callbacks to be executed in this step.
    public init(context: FlowContext, workflow: Workflow, input: [String: Any], actions: [any Callback]) {
        self.callbacksList = actions
        self.originalJson = input
        super.init(context: context, workflow: workflow, input: input, actions: actions)
    }

    /// Builds the JSON payload for submission to the Journey authenticate endpoint.
    ///
    /// - Returns: A dictionary containing `authId` and `callbacks` payloads.
    private func asJson() -> [String: Any] {
        var result: [String: Any] = [:]
        result[authIdKey] = originalJson[authIdKey] as? String ?? ""

        let payloads: [[String: Any]] = callbacksList
            .map { $0.payload() }
            .filter { !$0.isEmpty }

        result[JourneyConstants.callbacks] = payloads
        return result
    }

    /// Converts this node to a Request ready to be sent by the workflow.
    ///
    /// - Returns: A `Request` configured with URL, headers, and JSON body for the authenticate endpoint.
    override public func asRequest() -> Request {
        let config = workflow.config as? JourneyConfig
        let realm = config?.realm ?? "root"
        let baseURL = config?.serverUrl ?? ""

        var request = Request()
        request.url("\(baseURL)/json/realms/\(realm)/authenticate")
        request.header(name: JourneyConstants.contentType,  value: JourneyConstants.applicationJson)
        request.header(name: JourneyConstants.acceptApiVersion, value: JourneyConstants.resource21Protocol10)
        request.body(body: asJson())
        
        // Allow callbacks to intercept and modify the request (e.g., add headers)
        for callback in actions {
            if let interceptor = callback as? RequestInterceptor {
                request = interceptor.intercept(context: context, request: request)
            }
        }
        
        return request
    }
}
