//
//  Connector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate

extension ContinueNode {
    /// Extension property to get the id of a Connector.
    public var id: String {
        return (self as? Connector)?.idValue ?? ""
    }
    
    /// Extension property to get the name of a Connector.
    public var name: String {
        return (self as? Connector)?.nameValue ?? ""
    }
    
    /// Extension property to get the description of a Connector.
    public var description: String {
        return (self as? Connector)?.descriptionValue ?? ""
    }
    
    /// Extension property to get the category of a Connector.
    public var category: String {
        return (self as? Connector)?.categoryValue ?? ""
    }
}


/// Class representing a Connector.
///- property context: The FlowContext of the ContinueNode.
///- property davinci: The Davinci Flow of the ContinueNode.
///- property input: The input JsonObject of the ContinueNode.
///- property collectors: The collectors of the ContinueNode.
class Connector: ContinueNode, @unchecked Sendable {
    
    /// Initializer to create a new instance of Connector.
    /// - Parameters:
    ///   - context: The FlowContext of the ContinueNode.
    ///   - davinci: The Davinci Flow of the ContinueNode.
    ///   - input: The input JsonObject of the ContinueNode.
    ///   - collectors: The collectors of the ContinueNode.
    init(context: FlowContext, davinci: DaVinci, input: [String: Any], collectors: Collectors) {
        super.init(context: context, workflow: davinci, input: input, actions: collectors)
    }
    
    /// Function to convert the connector to a dictionary.
    /// - returns: The connector as a JsonObject.
    private func asJson() -> [String: Any] {
        var parameters: [String: Any] = [:]
        if let eventType = collectors.eventType() {
            parameters[Constants.eventType] = eventType
        }
        parameters[Constants.data] = collectors.asJson()
        
        return [
            Constants.id: (input[Constants.id] as? String) ?? "",
            Constants.eventName: (input[Constants.eventName] as? String) ?? "continue",
            Constants.parameters: parameters
        ]
    }
    
    /// Lazy property to get the id of the connector.
    lazy var idValue: String = {
        return input[Constants.id] as? String ?? ""
    }()
    
    /// Lazy property to get the name of the connector.
    lazy var nameValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.name] as? String ?? ""
    }()
    
    /// Lazy property to get the description of the connector.
    lazy var descriptionValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.description] as? String ?? ""
    }()
    
    /// Lazy property to get the category of the connector.
    lazy var categoryValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.category] as? String ?? ""
    }()
    
    /// Function to convert the connector to a Request.
    /// - Returns: The connector as a Request.
    override func asRequest() -> Request {
        var request = Request()
        
        let links: [String: Any]? = input[Constants._links] as? [String: Any]
        let next = links?[Constants.next] as? [String: Any]
        let href = next?[Constants.href] as? String ?? ""
        
        request.url(href)
        request.header(name: Request.Constants.contentType, value: Request.ContentType.json.rawValue)
        request.body(body: asJson())
        
        for collector in actions {
            if let interceptor = collector as? RequestInterceptor {
                request = interceptor.intercept(context: context, request: request)
            }
        }
        return request
    }
}

/// A module to set the `ContinueNode` in the `FlowContex`.
public class ContinueNodeModule {
    /// Initializes a new instance of `ContinueNodeModule`.
    public init() {}
    
    /// The configuration for the ContinueNodeModule.
    public static let config: Module<Void> = Module.of(setup: { setup in
        setup.node { @Sendable context, node in
            if let continueNode = node as? ContinueNode {
                context.flowContext.set(key: SharedContext.Keys.continueNode, value: continueNode)
            }
            return node
        }
    })
}

extension SharedContext.Keys {
    /// The key used to store the Continue Node value in the shared context.
    public static let continueNode = "com.pingidentity.davinci.CONTINUE_NODE"
}
