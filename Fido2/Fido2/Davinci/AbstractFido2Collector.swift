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

public class AbstractFido2Collector: FieldCollector<[String: Any]>, DaVinciAware, Submittable, @unchecked Sendable {    
    /// Return event type
    public func eventType() -> String {
        return Constants.submit
    }
    
    public var davinci: DaVinci?
    
    public var logger: Logger? {
        return davinci?.config.logger
    }
    
    public static func getCollector(with json: [String: Any]) -> AbstractFido2Collector? {
        guard let action = json[FidoConstants.FIELD_ACTION] as? String else {
            return nil
        }
        switch action {
        case FidoConstants.ACTION_REGISTER:
            return Fido2RegistrationCollector(with: json)
        case FidoConstants.ACTION_AUTHENTICATE:
            return Fido2AuthenticationCollector(with: json)
        default:
            return nil
        }
    }
}
