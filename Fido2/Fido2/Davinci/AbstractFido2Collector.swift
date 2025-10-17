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

/// An abstract base class for FIDO2 collectors in a DaVinci flow.
public class AbstractFido2Collector: FieldCollector<[String: Any]>, DaVinciAware, Submittable, @unchecked Sendable {    
    
    /// The DaVinci instance, providing access to configuration and logging.
    public var davinci: DaVinci?
    
    /// The logger for recording FIDO2 related events.
    public var logger: Logger? {
        return davinci?.config.logger
    }
    
    /// The FIDO2 instance, used for FIDO2 operations.
    var fido2: Fido2 = Fido2.shared
    
    /// Returns the event type for submission.
    public func eventType() -> String {
        return Constants.submit
    }
    
    /// A factory method to create the appropriate FIDO2 collector based on the action specified in the JSON payload.
    ///
    /// - Parameter json: The JSON payload from the server.
    /// - Throws: An error if the action is invalid or unsupported.
    /// - Returns: An instance of a concrete `AbstractFido2Collector` subclass.
    public static func getCollector(with json: [String: Any]) throws -> AbstractFido2Collector {
        guard let action = json[FidoConstants.FIELD_ACTION] as? String else {
            throw FidoError.invalidAction
        }
        switch action {
        case FidoConstants.ACTION_REGISTER:
            return Fido2RegistrationCollector(with: json)
        case FidoConstants.ACTION_AUTHENTICATE:
            return Fido2AuthenticationCollector(with: json)
        default:
            throw FidoError.unsupportedAction(action)
        }
    }
}
