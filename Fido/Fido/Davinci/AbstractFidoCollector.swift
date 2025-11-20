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
import AuthenticationServices

/// An abstract base class for Fido collectors in a DaVinci flow.
public class AbstractFidoCollector: FieldCollector<[String: Any]>, DaVinciAware, Submittable, @unchecked Sendable {    
    
    /// The DaVinci instance, providing access to configuration and logging.
    public var davinci: DaVinci?
    
    /// The logger for recording Fido related events.
    public var logger: Logger? {
        return davinci?.config.logger
    }
    
    /// Private storage for the Fido instance
    private var _fido: Fido?
    
    /// Fido manager instance - defaults to shared singleton but can be injected for testing.
    @MainActor
    var fido: Fido {
        get { _fido ?? Fido.shared }
        set { _fido = newValue }
    }
    
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
    
    /// Handles errors that occur during FIDO operations and transforms them into WebAuthn-spec-compliant errors.
    ///
    /// This method converts `ASAuthorizationError` codes and `FidoError` types into human-readable error information
    /// based on the WebAuthn specification. The transformed error is returned to the caller.
    ///
    /// - Parameter error: The error to handle and transform.
    /// - Returns: A transformed `FidoError` that is more human-readable and spec-compliant.
    public func handleError(error: Error) -> FidoError {
        logger?.e("Handling FIDO error: \(error.localizedDescription)", error: error)
        
        // Check if it's a FidoError first
        if let fidoError = error as? FidoError {
            switch fidoError {
            case .timeout:
                logger?.d("FIDO operation timed out")
                return .timeout
            case .unsupportedAction(let message):
                logger?.d("FIDO ERROR NOT SUPPORTED: \(message)")
                return .unsupportedAction(message)
            case .invalidResponse:
                logger?.d("FIDO invalid response")
                return .invalidResponse
            case .invalidChallenge:
                logger?.d("FIDO invalid challenge")
                return .invalidChallenge
            case .invalidWindow:
                logger?.d("FIDO invalid window")
                return .invalidWindow
            case .invalidAction:
                logger?.d("FIDO invalid action")
                return .invalidAction
            case .missingParameters(let message):
                logger?.d("FIDO missing parameters: \(message)")
                return .missingParameters(message)
            }
        }
        
        let nsError = error as NSError
        
        switch nsError.domain {
        case ASAuthorizationError.errorDomain:
            switch nsError.code {
            case ASAuthorizationError.canceled.rawValue:
                logger?.d("Credential operation cancelled")
                return .unsupportedAction(FidoConstants.ERROR_NOT_ALLOWED_MESSAGE)
            case ASAuthorizationError.invalidResponse.rawValue:
                logger?.d("DOM exception occurred: InvalidStateError")
                return .invalidResponse
            case ASAuthorizationError.notHandled.rawValue:
                logger?.d("DOM exception occurred: NotSupportedError")
                return .unsupportedAction("Operation not supported")
            case ASAuthorizationError.unknown.rawValue:
                logger?.d("Unknown error occurred")
                return .unsupportedAction("Unknown error: \(error.localizedDescription)")
            default:
                logger?.d("Unknown authorization error occurred")
                return .unsupportedAction("Unknown error: \(error.localizedDescription)")
            }
        default:
            logger?.d("Unknown error occurred")
            return .unsupportedAction("Unknown error: \(error.localizedDescription)")
        }
    }
}
