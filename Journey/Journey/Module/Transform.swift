//
//  Transform.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

/// Define the module that transforms the response from Journey to a `Node`.
public class NodeTransformModule: @unchecked Sendable {
    
    /// Initializes a new instance of `SessionModule`.
    public init() {}
    
    /// The module configuration for transforming the response from Journey to `Node`.
    public static let config: Module<Void> = Module.of(setup: { setup in
        setup.transform { @Sendable flowContext, response in
            let status = response.status()
            
            let body = response.body()
            
            // Check for 4XX errors that are unrecoverable
            if (400..<500).contains(status) {
                let json = try response.json(data: response.data)
                let message = json[JourneyConstants.message] as? String ?? ""
                return ErrorNode(status: status, input: json, message: message, context: flowContext)
            }
            
            // Handle success (2XX) responses
            if status == 200 {
                let json = try response.json(data: response.data)
                return await transform(context: flowContext, journey: setup.workflow, json: json)
            }
            
            // Handle success (3XX) responses
            if (300..<400).contains(status) {
                let locationHeader = response.header(name: JourneyConstants.location) ?? ""
                return FailureNode(cause: ApiError.error(status, [:], "Location: \(String(describing: locationHeader))" ))
            }
            
            // 5XX errors are treated as unrecoverable failures
            let json = try response.json(data: response.data)
            return FailureNode(cause: ApiError.error(status, json, body))
        }
    })
    
    /// Transforms the response JSON into a `Node` object.
    /// - Parameters:
    /// - context: The flow context containing the current state of the journey.
    /// - journey: The current journey being processed.
    /// - json: The JSON response data to be transformed.
    /// - Returns: A `Node` representing the transformed response.
    private static func transform(context: FlowContext, journey: Journey, json: [String: Any]) async -> Node {
        var callbacks: Callbacks = []
        
        if json.keys.contains(JourneyConstants.authId) {
            if let callbackArray = json[JourneyConstants.callbacks] as? [[String: any Sendable]] {
                callbacks.append(contentsOf: await CallbackRegistry.shared.callback(from: callbackArray))
            }
            
            let node = JourneyContinueNode(context: context, workflow: journey, input: json, actions: callbacks)
            await CallbackRegistry.shared.inject(continueNode: node, journey: journey)
            
            return node
        } else {
            var value: String = ""
            var successUrl: String = ""
            var realm: String = ""
            
            if let token = json[JourneyConstants.tokenId] as? String {
                value = token
            }
            
            if let success = json[JourneyConstants.successUrl] as? String {
                successUrl = success
            }
            
            if let realmName = json[JourneyConstants.realmName] as? String {
                realm = realmName
            }
            
            let ssoToken = SSOTokenImpl(value: value, successUrl: successUrl, realm: realm)
            return SuccessNode(input: json, session: ssoToken)
        }
    }
}

/// Represents API errors that occur during response transformation.
public enum ApiError: Error, @unchecked Sendable {
    /// An error containing an HTTP status code, a JSON object, and a descriptive message.
    /// - Parameters:
    ///   - status: The HTTP status code of the error.
    ///   - json: The JSON data associated with the error.
    ///   - message: A descriptive message explaining the error.
    case error(Int, [String: Any], String)
}
