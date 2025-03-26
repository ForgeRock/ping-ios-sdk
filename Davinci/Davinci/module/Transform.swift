//
//  Transform.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate

/// Module for transforming the response from DaVinci to `Node`.
public class NodeTransformModule {
    
    /// The module configuration for transforming the response from DaVinci to `Node`.
    public static let config: Module<Void> = Module.of(setup: { setup in
        setup.transform { @Sendable flowContext, response in
            let status = response.status()
            
            let body = response.body()
            
            // Check for 4XX errors that are unrecoverable
            if (400..<500).contains(status) {
                let json = try response.json(data: response.data)
                let message = json[Constants.message] as? String ?? ""
                
                // Filter out client-side "timeout" related unrecoverable failures
                if json[Constants.code] as? Int == Constants.code_1999 || json[Constants.code] as? String == Constants.requestTimedOut {
                    return FailureNode(cause: ApiError.error(status, json, body))
                }
                
                // Filter our "PingOne Authentication Connector" unrecoverable failures
                if let connectorId = json[Constants.connectorId] as? String, connectorId == Constants.pingOneAuthenticationConnector,
                   let capabilityName = json[Constants.capabilityName] as? String,
                   [Constants.returnSuccessResponseRedirect, Constants.setSession].contains(capabilityName) {
                    return FailureNode(cause: ApiError.error(status, json, body))
                }
                
                // If we're still here, we have a 4XX failure that should be recoverable
                return ErrorNode(status: status, input: json, message: message)
            }
            
            // Handle success (2XX) responses
            if status == 200 {
                let json = try response.json(data: response.data)
                
                // Filter out 2XX errors with 'failure' status
                if let failedStatus = json[Constants.status] as? String, failedStatus == Constants.FAILED {
                    return FailureNode(cause: ApiError.error(status, json, body))
                }
                
                // Filter out 2XX errors with error object
                if let error = json[Constants.error] as? [String: Any], !error.isEmpty {
                    return FailureNode(cause: ApiError.error(status, json, body))
                }
                
                return await transform(context: flowContext, davinci: setup.workflow, json: json)
            }
            
            // Handle success (3XX) responses
            if (300..<400).contains(status) {
                let locationHeader = response.header(name: Constants.location) ?? ""
                return FailureNode(cause: ApiError.error(status, [:], "Location: \(String(describing: locationHeader))" ))
            }
            
            // 5XX errors are treated as unrecoverable failures
            let json = try response.json(data: response.data)
            return FailureNode(cause: ApiError.error(status, json, body))
        }
        
    })
    
    private static func transform(context: FlowContext, davinci: DaVinci, json: [String: Any]) async -> Node {
        // If authorizeResponse is present, return success
        if let _ = json[Constants.authorizeResponse] as? [String: Any] {
            return SuccessNode(input: json, session: SessionResponse(json: json))
        }
        
        var collectors: Collectors = []
        if let _ = json[Constants.form] {
            await collectors.append(contentsOf: Form.parse(json: json))
        }
        
        let connector = Connector(context: context, davinci: davinci, input: json, collectors: collectors)
        await CollectorFactory.shared.inject(continueNode: connector)
        return connector
    }
}


/// Represents a session response parsed from a JSON object.
public struct SessionResponse: Session, @unchecked Sendable {
    /// The raw JSON data of the session response.
    public let json: [String: Any]
    
    /// Initializes a new session response with the given JSON data.
    /// - Parameter json: The JSON data representing the session response.
    public init(json: [String: Any] = [:]) {
        self.json = json
    }
    
    /// The session value extracted from the JSON response.
    /// - Returns: A string representing the session code or an empty string if not available.
    public var value: String {
        get {
            let authResponse = json[Constants.authorizeResponse] as? [String: Any]
            return authResponse?[Constants.code] as? String ?? ""
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
