//
//  MetadataCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingJourneyPlugin

/// A callback for providing metadata that can transform into specialized callbacks based on content.
public class MetadataCallback: AbstractCallback, MetadataCallbackProtocol, ObservableObject, @unchecked Sendable, ContinueNodeAware, JourneyAware {
    
    public var journey: Journey?
    
    public var continueNode: ContinueNode?

    /// The metadata value
    private(set) public var value: [String: Any] = [:]
    
    /// Initializes a new instance of `MetadataCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.data:
            if let dictValue = value as? [String: Any] {
                self.value = dictValue
            }
        default:
            break
        }
    }

    public override func initialize(with json: [String: Any]) -> any Callback {
        _ = super.initialize(with: json)

        // Check if we should create a specialized callback
        if isProtectInitialize() {
            if let callbackClass =  (CallbackRegistry.shared.callbacks[Constants.PING_ONE_PROTECT_INITIALIZE_CALLBACK]) {
                return callbackClass.init().initialize(with: json)
            }
        } else if isProtectEvaluation() {
            if let callbackClass =  (CallbackRegistry.shared.callbacks[Constants.PING_ONE_PROTECT_EVALUATION_CALLBACK]) {
                return callbackClass.init().initialize(with: json)
            }
        } else if isFidoRegistration() {
            if let callbackClass =  (CallbackRegistry.shared.callbacks[Constants.FIDO_2_REGISTRATION_CALLBACK]) {
                let callback = callbackClass.init()
                if var journeyAware = callback as? JourneyAware {
                    journeyAware.journey = self.journey
                }
                if var continueNodeAware = callback as? ContinueNodeAware {
                    continueNodeAware.continueNode = self.continueNode
                }
                return callback.initialize(with: self.json)
            }
        } else if isFidoAuthentication() {
            if let callbackClass =  (CallbackRegistry.shared.callbacks[Constants.FIDO_2_AUTHENTICATION_CALLBACK]) {
                let callback = callbackClass.init()
                if var journeyAware = callback as? JourneyAware {
                    journeyAware.journey = self.journey
                }
                if var continueNodeAware = callback as? ContinueNodeAware {
                    continueNodeAware.continueNode = self.continueNode
                }
                return callback.initialize(with: self.json)
            }
        }

        return self
    }

    /// Checks if this metadata represents FIDO registration
    private func isFidoRegistration() -> Bool {
        // _action is provided AM version >= AM 7.1
        if let action = value[Constants.ACTION] as? String, action == Constants.WEBAUTHN_REGISTRATION {
            return true
        }

        // Checking for existence and content of _TYPE and either PUB_KEY_CRED_PARAMS
        // or _PUB_KEY_CRED_PARAMS
        if let type = value[Constants.TYPE] as? String, type == Constants.WEB_AUTHN {
            return value.keys.contains(Constants.PUB_KEY_CRED_PARAMS) || value.keys.contains(Constants._PUB_KEY_CRED_PARAMS)
        }

        return false
    }

    /// Checks if this metadata represents FIDO authentication
    private func isFidoAuthentication() -> Bool {
        // _action is provided AM version >= AM 7.1
        if let action = value[Constants.ACTION] as? String, action == Constants.WEBAUTHN_AUTHENTICATION {
            return true
        }

        // Checking for existence and content of _TYPE and not with PUB_KEY_CRED_PARAMS
        // and _PUB_KEY_CRED_PARAMS
        if let type = value[Constants.TYPE] as? String, type == Constants.WEB_AUTHN {
            return value.keys.contains(Constants.ALLOW_CREDENTIALS) || value.keys.contains(Constants._ALLOW_CREDENTIALS)
        }

        return false
    }

    /// Checks if this metadata represents PingOne Protect initialization
    private func isProtectInitialize() -> Bool {
        guard let type = value[Constants.TYPE] as? String, type == Constants.PING_ONE_PROTECT,
              let action = value[Constants.ACTION] as? String, action == Constants.PROTECT_INITIALIZE else {
            return false
        }
        return true
    }

    /// Checks if this metadata represents PingOne Protect evaluation
    private func isProtectEvaluation() -> Bool {
        guard let type = value[Constants.TYPE] as? String, type == Constants.PING_ONE_PROTECT,
              let action = value[Constants.ACTION] as? String, action == Constants.PROTECT_RISK_EVALUATION else {
            return false
        }
        return true
    }
}

private enum Constants {
    fileprivate static let PING_ONE_PROTECT_INITIALIZE_CALLBACK = "PingOneProtectInitializeCallback"
    fileprivate static let PING_ONE_PROTECT_EVALUATION_CALLBACK = "PingOneProtectEvaluationCallback"
    fileprivate static let FIDO_2_REGISTRATION_CALLBACK = "FidoRegistrationCallback"
    fileprivate static let FIDO_2_AUTHENTICATION_CALLBACK = "FidoAuthenticationCallback"
    fileprivate static let ACTION = "_action"
    fileprivate static let TYPE = "_type"
    fileprivate static let WEBAUTHN_REGISTRATION = "webauthn_registration"
    fileprivate static let WEB_AUTHN = "WebAuthn"
    fileprivate static let _PUB_KEY_CRED_PARAMS = "_pubKeyCredParams"
    fileprivate static let PUB_KEY_CRED_PARAMS = "pubKeyCredParams"
    fileprivate static let WEBAUTHN_AUTHENTICATION = "webauthn_authentication"
    fileprivate static let PING_ONE_PROTECT = "PingOneProtect"
    fileprivate static let PROTECT_INITIALIZE = "protect_initialize"
    fileprivate static let PROTECT_RISK_EVALUATION = "protect_risk_evaluation"
    fileprivate static let ALLOW_CREDENTIALS = "allowCredentials"
    fileprivate static let _ALLOW_CREDENTIALS = "_allowCredentials"
}
