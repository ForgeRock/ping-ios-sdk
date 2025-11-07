//
//  FidoCallback.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
import PingOrchestrate
import PingLogger
import AuthenticationServices

/// Abstract base class for FIDO callbacks in PingOne Journey workflows.
///
/// This class provides common functionality for handling FIDO operations within
/// Journey workflows, including error handling and value setting.
/// It manages the interaction between FIDO operations and the Journey framework.
public class FidoCallback: AbstractCallback, JourneyAware, ContinueNodeAware, @unchecked Sendable {
    
    /// The Journey `ContinueNode` that this callback is associated with.
    public var continueNode: ContinueNode?
    
    /// The `Journey` instance that this callback is associated with.
    public var journey: Journey?
    
    /// Logger instance for this callback, obtained from the workflow configuration.
    public var logger: Logger? {
        return journey?.config.logger
    }
    
    /// Private storage for the Fido instance
    private var _fido: Fido?
    
    /// Fido manager instance - defaults to shared singleton but can be injected for testing.
    @MainActor
    var fido: Fido {
        get { _fido ?? Fido.shared }
        set { _fido = newValue }
    }
    
    /// This method is an override from `AbstractCallback` and is not used in this context.
    public override func initValue(name: String, value: Any) {
        
    }

    /// Sets a value to the `HiddenValueCallback` associated with the WebAuthn outcome.
    ///
    /// - Parameter value: The value to set for the WebAuthn outcome.
    public func valueCallback(value: String) {
        logger?.d("Setting WebAuthn outcome value")
        if let valueCallback = continueNode?.callbacks.first(where: { ($0 as? HiddenValueCallback)?.hiddenId == FidoConstants.WEB_AUTHN_OUTCOME }) as? HiddenValueCallback {
            valueCallback.value = value
        } else {
            logger?.w("WebAuthn outcome callback not found", error: nil)
        }
    }
    
    /// Handles errors that occur during FIDO operations.
    ///
    /// This method converts `ASAuthorizationError` codes into error messages that the Journey server can process.
    /// - Parameter error: The error to handle and convert.
    public func handleError(error: Error) {
        logger?.e("Handling FIDO error: \(error.localizedDescription)", error: error)
        
        // Check if it's a FidoError first
        if let fidoError = error as? FidoError {
            switch fidoError {
            case .timeout:
                logger?.d("FIDO operation timed out")
                setError(error: FidoConstants.ERROR_TIMEOUT, message: "Operation timedout")
                return
            default:
                break
            }
        }
        
        let nsError = error as NSError
        
        switch nsError.domain {
        case ASAuthorizationError.errorDomain:
            switch nsError.code {
            case ASAuthorizationError.canceled.rawValue:
                logger?.d("Credential creation cancelled")
                setError(error: FidoConstants.ERROR_NOT_ALLOWED, message: FidoConstants.ERROR_NOT_ALLOWED_MESSAGE)
            case ASAuthorizationError.invalidResponse.rawValue:
                logger?.d("DOM exception occurred: InvalidStateError")
                setError(error: FidoConstants.ERROR_INVALID_STATE, message: error.localizedDescription)
            case ASAuthorizationError.notHandled.rawValue:
                logger?.d("DOM exception occurred: NotSupportedError")
                setError(error: FidoConstants.ERROR_NOT_SUPPORTED, message: error.localizedDescription)
            case ASAuthorizationError.unknown.rawValue:
                logger?.d("Unknown error occurred")
                setError(error: FidoConstants.ERROR_UNKNOWN, message: error.localizedDescription)
            default:
                logger?.d("Unknown error occurred")
                setError(error: FidoConstants.ERROR_UNKNOWN, message: error.localizedDescription)
            }
        default:
            logger?.d("Unknown error occurred")
            setError(error: FidoConstants.ERROR_UNKNOWN, message: error.localizedDescription)
        }
    }

    /// Sets an error value in the WebAuthn outcome callback.
    ///
    /// - Parameters:
    ///  - error: The error type or code.
    ///  - message: A descriptive message about the error.
    private func setError(error: String?, message: String?) {
        logger?.d("Setting error - type: \(error ?? "nil"), message: \(message ?? "nil")")
        if let valueCallback = continueNode?.callbacks.first(where: { ($0 as? HiddenValueCallback)?.hiddenId == FidoConstants.WEB_AUTHN_OUTCOME }) as? HiddenValueCallback {
            let errorValue = "\(FidoConstants.ERROR_PREFIX)\(error ?? ""):\(message ?? "")"
            logger?.d("Setting error value: \(errorValue)")
            valueCallback.value = errorValue
        } else {
            logger?.e("WebAuthn outcome callback not found for error setting", error: nil)
        }
    }
}

