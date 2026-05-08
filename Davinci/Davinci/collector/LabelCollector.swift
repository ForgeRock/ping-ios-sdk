// 
//  LabelCollector.swift
//  PingDavinci
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingDavinciPlugin

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
    /// Optional rich content with template text and link replacements.
    public private(set) var richContent: RichContent?

    /// Initializes a new instance of `LabelCollector`.
    /// - Parameter json: The json to initialize from.
    public required init(with json: [String : Any]) {
        content = json[Constants.content] as? String ?? ""
        key = json[Constants.key] as? String ?? ""

        if let richContentDict = json[Constants.richContent] as? [String: Any],
           let richContentContent = richContentDict[Constants.content] as? String {
            var replacements: [String: RichContentReplacement] = [:]
            if let replacementsDict = richContentDict[Constants.replacements] as? [String: [String: Any]] {
                for (replacementKey, replacementDict) in replacementsDict {
                    let replacement = RichContentReplacement(
                        value: replacementDict[Constants.value] as? String ?? "",
                        href: replacementDict[Constants.href] as? String,
                        type: replacementDict[Constants.type] as? String ?? "",
                        target: replacementDict[Constants.target] as? String
                    )
                    replacements[replacementKey] = replacement
                }
            }
            self.richContent = RichContent(content: richContentContent, replacements: replacements)
        }
    }
    
    /// Initializes the `LabelCollector` with the given value. The `LabelCollector` does not hold any value.
    /// - Parameter input: The value to initialize the collector with.
    public func initialize(with value: Any) {}
    
    /// Function returning the `Payload` of the LabelCollector. This is a function that returns `Never` as a _nonreturning_ function as the LabelCollector has no payload to return.
    public func payload() -> Never? {
        return nil
    }
}
