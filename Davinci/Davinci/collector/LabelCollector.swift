// 
//  LabelCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Class representing a LABEL type.
/// It conforms to the `Collector` protocol and displays a label on the form.
public class LabelCollector: Collector, @unchecked Sendable {
    
    /// The UUID of the field collector.
    public var id: String {
        return key
    }
    /// The key of the label collector.
    public private(set) var key: String = ""
    /// The label content.
    public private(set) var content: String = ""
    
    /// Initializes a new instance of `LabelCollector`.
    /// - Parameter json: The json to initialize from.
    public required init(with json: [String : Any]) {
        content = json[Constants.content] as? String ?? ""
        key = json[Constants.key] as? String ?? ""
    }
    
    /// Initializes the `LabelCollector` with the given value. The `LabelCollector` does not hold any value.
    /// - Parameter input: The value to initialize the collector with.
    public func initialize(with value: Any) {}
    
    /// Function returning the `Payload` of the LabelCollector. This is a function that returns `Never` as a _nonreturning_ function as the LabelCollector has no payload to return.
    public func payload() -> Never? {
        return nil
    }
}
