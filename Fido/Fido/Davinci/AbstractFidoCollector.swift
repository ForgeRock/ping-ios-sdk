//
//  AbstractFidoCollector.swift
//  Fido
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin
import PingLogger
import PingOrchestrate
import AuthenticationServices

/// An abstract base class for Fido collectors in a DaVinci flow.
public class AbstractFidoCollector: AnyFieldCollector, DaVinciAware, Submittable, ActionKeyProvider, @unchecked Sendable {

    public private(set) var type: String = ""
    public private(set) var key: String = ""
    public private(set) var label: String = ""
    public private(set) var required: Bool = false
    /// The raw server-supplied `trigger` value for this DaVinci form field. Empty when the
    /// server omits the field. See `isAutomatic` for the derived launch semantics.
    public private(set) var trigger: String = ""

    /// DOMException name set when a FIDO operation fails; drives the DaVinci error response.
    public var errorCode: String?

    /// Supplies the DOMException name as `actionKey` when a FIDO error has occurred.
    public var actionKey: String? { errorCode }
    
    /// The UUID of the field collector.
    public var id: String {
        return key
    }
    
    public func anyPayload() -> Any? {
        return payload()
    }
    
    public func payload() -> [String: Any]? {
        fatalError(String(#function) + " must be overridden from subclasses")
    }
    
    public func initialize(with value: Any) {}
    
    public required init(with json: [String : Any]) {
        key = json[FidoConstants.key] as? String ?? ""
        type = json[FidoConstants.type] as? String ?? ""
        label = json[FidoConstants.label] as? String ?? ""
        required = json[FidoConstants.required] as? Bool ?? false
        trigger = json[FidoConstants.FIELD_TRIGGER] as? String ?? ""
        logger.d("FIDO collector trigger: \(trigger.isEmpty ? "<absent>" : trigger)")
    }

    /// Whether the FIDO ceremony should be launched automatically on render rather than
    /// gated behind a button.
    ///
    /// `false` when `trigger` is empty or absent, preserving today's button-gated behaviour for
    /// payloads that predate the `trigger` property. Otherwise `true` when `trigger` does not
    /// case-insensitively equal `FidoConstants.TRIGGER_BUTTON` — any confirmed or future
    /// non-`"BUTTON"` token is treated as automatic.
    public var isAutomatic: Bool {
        guard !trigger.isEmpty else { return false }
        return trigger.caseInsensitiveCompare(FidoConstants.TRIGGER_BUTTON) != .orderedSame
    }
    
    /// Validates this collector, returning a list of validation errors if any.
    /// - Returns: An array of `ValidationError`.
    public func validate() -> [ValidationError] {
        return []
    }

    /// The DaVinci instance, providing access to configuration and logging.
    public var davinci: DaVinci?
    
    /// The logger for recording Fido related events.
    public var logger: Logger {
        return davinci?.config.logger ?? LogManager.logger
    }
    
    /// Private storage for the Fido instance
    private var _fido: Fido?
    
    /// Fido manager instance - defaults to shared singleton but can be injected for testing.
    @MainActor
    var fido: Fido {
        get { _fido ?? Fido.shared }
        set { _fido = newValue }
    }
    
    /// Returns the event type for submission. Returns `"action"` when a FIDO error has occurred.
    public func eventType() -> String {
        return errorCode != nil ? FidoConstants.EVENT_TYPE_ACTION : FidoConstants.EVENT_TYPE_SUBMIT
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
    /// Sets `errorCode` to the appropriate WebAuthn DOMException name so the DaVinci server receives
    /// an `actionKey` on the next submission. Returns the transformed `FidoError` to the caller.
    ///
    /// - Parameter error: The error to handle and transform.
    /// - Returns: A transformed `FidoError` that is more human-readable and spec-compliant.
    public func handleError(error: Error) -> FidoError {
        logger.e("Handling FIDO error: \(error.localizedDescription)", error: error)

        if let fidoError = error as? FidoError {
            switch fidoError {
            case .timeout:
                logger.d("FIDO operation timed out")
                errorCode = FidoConstants.ERROR_TIMEOUT
                return .timeout
            case .unsupportedAction(let message):
                logger.d("FIDO ERROR NOT SUPPORTED: \(message)")
                errorCode = FidoConstants.ERROR_NOT_SUPPORTED
                return .unsupportedAction(message)
            case .invalidResponse:
                logger.d("FIDO invalid response")
                errorCode = FidoConstants.ERROR_INVALID_STATE
                return .invalidResponse
            case .invalidChallenge:
                logger.d("FIDO invalid challenge")
                errorCode = FidoConstants.ERROR_INVALID_STATE
                return .invalidChallenge
            case .invalidWindow:
                logger.d("FIDO invalid window")
                errorCode = FidoConstants.ERROR_UNKNOWN
                return .invalidWindow
            case .invalidAction:
                logger.d("FIDO invalid action")
                errorCode = FidoConstants.ERROR_NOT_SUPPORTED
                return .invalidAction
            case .missingParameters(let message):
                logger.d("FIDO missing parameters: \(message)")
                errorCode = FidoConstants.ERROR_NOT_SUPPORTED
                return .missingParameters(message)
            }
        }

        let nsError = error as NSError

        switch nsError.domain {
        case ASAuthorizationError.errorDomain:
            switch nsError.code {
            case ASAuthorizationError.canceled.rawValue:
                logger.d("Credential operation cancelled")
                errorCode = FidoConstants.ERROR_NOT_ALLOWED
                return .unsupportedAction(FidoConstants.ERROR_NOT_ALLOWED_MESSAGE)
            case ASAuthorizationError.failed.rawValue:
                logger.d("Credential operation failed")
                errorCode = FidoConstants.ERROR_NOT_ALLOWED
                return .unsupportedAction(FidoConstants.ERROR_NOT_ALLOWED_MESSAGE)
            case ASAuthorizationError.invalidResponse.rawValue:
                logger.d("DOM exception occurred: InvalidStateError")
                errorCode = FidoConstants.ERROR_INVALID_STATE
                return .invalidResponse
            case ASAuthorizationError.notHandled.rawValue:
                logger.d("DOM exception occurred: NotSupportedError")
                errorCode = FidoConstants.ERROR_NOT_SUPPORTED
                return .unsupportedAction("Operation not supported")
            case ASAuthorizationError.unknown.rawValue:
                logger.d("Unknown error occurred")
                errorCode = FidoConstants.ERROR_UNKNOWN
                return .unsupportedAction("Unknown error: \(error.localizedDescription)")
            default:
                logger.d("Unknown authorization error occurred")
                errorCode = FidoConstants.ERROR_UNKNOWN
                return .unsupportedAction("Unknown error: \(error.localizedDescription)")
            }
        default:
            logger.d("Unknown error occurred")
            errorCode = FidoConstants.ERROR_UNKNOWN
            return .unsupportedAction("Unknown error: \(error.localizedDescription)")
        }
    }
}
