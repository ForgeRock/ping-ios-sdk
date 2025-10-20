//
//  AbstractFidoCollector.swift
//  Fido
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

/// An abstract base class for Fido collectors in a DaVinci flow.
public class AbstractFidoCollector: FieldCollector<[String: Any]>, DaVinciAware, Submittable, @unchecked Sendable {    
    
    /// The DaVinci instance, providing access to configuration and logging.
    public var davinci: DaVinci?
    
    /// The logger for recording Fido related events.
    public var logger: Logger? {
        return davinci?.config.logger
    }
    
    /// The Fido instance, used for Fido operations.
    var fido: Fido = Fido.shared
    
    /// Returns the event type for submission.
    public func eventType() -> String {
        return FidoConstants.EVENT_TYPE_SUBMIT
    }
    
    /// A factory method to create the appropriate Fido collector based on the action specified in the JSON payload.
    ///
    /// - Parameter json: The JSON payload from the server.
    /// - Throws: An error if the action is invalid or unsupported.
    /// - Returns: An instance of a concrete `AbstractFidoCollector` subclass.
    public static func getCollector(with json: [String: Any]) throws -> AbstractFidoCollector {
        guard let action = json[FidoConstants.FIELD_ACTION] as? String else {
            throw FidoError.invalidAction
        }
        switch action {
        case FidoConstants.ACTION_REGISTER:
            return FidoRegistrationCollector(with: json)
        case FidoConstants.ACTION_AUTHENTICATE:
            return FidoAuthenticationCollector(with: json)
        default:
            throw FidoError.unsupportedAction(action)
        }
    }
}
