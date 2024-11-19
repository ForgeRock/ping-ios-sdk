//
//  Connector.swift
//  Davinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate

/// Extension to get the id of a ContinueNode.
extension ContinueNode {
    public var id: String {
        return (self as? Connector)?.idValue ?? ""
    }
    
    public var name: String {
        return (self as? Connector)?.nameValue ?? ""
    }
    
    public var description: String {
        return (self as? Connector)?.descriptionValue ?? ""
    }
    
    public var category: String {
        return (self as? Connector)?.categoryValue ?? ""
    }
    
}


/// Class representing a Connector.
///- property context: The FlowContext of the ContinueNode.
///- property davinci: The Davinci Flow of the ContinueNode.
///- property input: The input JsonObject of the ContinueNode.
///- property collectors: The collectors of the ContinueNode.
class Connector: ContinueNode {
    
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
            Constants.eventName: (input[Constants.eventName] as? String) ?? "",
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
        let request = Request()
        
        let links: [String: Any]? = input[Constants._links] as? [String: Any]
        let next = links?[Constants.next] as? [String: Any]
        let href = next?[Constants.href] as? String ?? ""
        
        request.url(href)
        request.header(name: Request.Constants.contentType, value: Request.ContentType.json.rawValue)
        request.body(body: asJson())
        return request
    }
}
