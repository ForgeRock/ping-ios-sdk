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
    public let id = UUID()
    /// The label content.
    public private(set) var content: String = ""
    
    /// Initializes a new instance of `LabelCollector`.
    /// - Parameter json: The json to initialize from.
    public required init(with json: [String : Any]) {
        content = json[Constants.content] as? String ?? ""
    }
}
