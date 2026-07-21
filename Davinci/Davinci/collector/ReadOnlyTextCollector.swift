//
//  ReadOnlyTextCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin

/// This class handles the response from a DaVinci form field of inputType READ_ONLY_TEXT .
/// It displays read-only text content such as agreement/terms-of-service text.
///
/// Example JSON:
/// ```json
/// {
///   "type": "AGREEMENT",
///   "inputType": "READ_ONLY_TEXT",
///   "key": "agreement",
///   "content": "This is example agreement text...",
///   "titleEnabled": true,
///   "title": "Terms of Service Agreement",
///   "agreement": {
///     "id": "6ff30c9e-cd98-4fe5-85ca-01111ca20702",
///     "useDynamicAgreement": false
///   },
///   "enabled": true
/// }
/// ```
public class ReadOnlyTextCollector: Collector, @unchecked Sendable {
    
    /// The UUID of the collector.
    public var id: String {
        return key
    }
    
    /// The key identifier for this collector, used as the form field key during submission.
    public private(set) var key: String = ""
    
    /// The type of this collector (e.g., "AGREEMENT").
    public private(set) var type: String = ""
    
    /// The agreement text content to display to the user.
    public private(set) var content: String = ""
    
    /// The title of the agreement (shown when `titleEnabled` is true).
    public private(set) var title: String = ""
    
    /// Whether to display the `title` above the agreement content.
    public private(set) var titleEnabled: Bool = false
    
    /// Whether this collector is enabled.
    public private(set) var enabled: Bool = true
    
    /// The unique ID of the agreement definition.
    public private(set) var agreementId: String = ""
    
    /// Whether the agreement content is loaded dynamically.
    public private(set) var useDynamicAgreement: Bool = false
    
    /// Initializes a new instance of `ReadOnlyTextCollector`.
    /// - Parameter json: The json to initialize from.
    public required init(with json: [String: Any]) {
        key = json[Constants.key] as? String ?? ""
        type = json[Constants.type] as? String ?? ""
        content = json[Constants.content] as? String ?? ""
        title = json[Constants.title] as? String ?? ""
        titleEnabled = json[Constants.titleEnabled] as? Bool ?? false
        enabled = json[Constants.enabled] as? Bool ?? true
        
        if let agreement = json[Constants.agreement] as? [String: Any] {
            agreementId = agreement[Constants.id] as? String ?? ""
            useDynamicAgreement = agreement[Constants.useDynamicAgreement] as? Bool ?? false
        }
    }
    
    /// Initializes the `ReadOnlyTextCollector` with the given value. The `ReadOnlyTextCollector` does not hold any value.
    /// - Parameter value: The value to initialize the collector with.
    public func initialize(with value: Any) {}
    
    /// Function returning the `Payload` of the ReadOnlyTextCollector. This is a function that returns `Never` as a _nonreturning_ function as the ReadOnlyTextCollector has no payload to return.
    public func payload() -> Never? {
        return nil
    }
}
