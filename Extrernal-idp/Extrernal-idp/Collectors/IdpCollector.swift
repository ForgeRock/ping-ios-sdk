//
//  IdpCollector.swift
//  Extrernal-idp
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci
import PingOrchestrate

public class IdpCollector: FieldCollector, ContinueNodeAware {
    public var continueNode: ContinueNode?
    
    public var value: String = ""
    
    public required init(with json: [String : Any]) {
        super.init(with: json)
        
        // Extract the value from the input dictionary
        if let stringValue = json[Constants.value] as? String {
            value = stringValue
        }
    }
    
    
}
