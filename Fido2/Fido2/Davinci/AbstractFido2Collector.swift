//
//  AbstractFido2Collector.swift
//  Fido2
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci
import PingLogger
import PingOrchestrate

public class AbstractFido2Collector: Collector, ContinueNodeAware, DaVinciAware, @unchecked Sendable {
    public typealias T = [String: Any]
    
    public var id: String {
        return key
    }
    
    public var continueNode: ContinueNode?
    public var davinci: DaVinci?
    
    public var logger: Logger? {
        return davinci?.config.logger
    }
    
    public var key: String = ""
    public var label: String = ""
    public var trigger: String = ""
    public var required: Bool = false
    
    public required init(with json: [String : Any]) {
        self.key = json[FidoConstants.FIELD_KEY] as? String ?? ""
        self.label = json[FidoConstants.FIELD_LABEL] as? String ?? ""
        self.trigger = json[FidoConstants.FIELD_TRIGGER] as? String ?? ""
        self.required = json[FidoConstants.FIELD_REQUIRED] as? Bool ?? false
    }
    
    public func initialize(with value: Any) {
        
    }
    
    public func payload() -> [String : Any]? {
        return nil
    }
}
