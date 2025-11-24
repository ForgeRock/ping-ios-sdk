//
//  MetadataCallback.swift
//  Journey
//
// Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENSE file for details.
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
        // Specialization now occurs in CallbackRegistry.callback(from:).
        return self
    }

    // The following helpers remain in case other parts of the app need them in the future,
    // but specialization is no longer performed here.
    private func isFidoRegistration() -> Bool {
        if let action = value[Constants.ACTION] as? String, action == Constants.WEBAUTHN_REGISTRATION {
            return true
        }
        if let type = value[Constants.TYPE] as? String, type == Constants.WEB_AUTHN {
            return value.keys.contains(Constants.PUB_KEY_CRED_PARAMS) || value.keys.contains(Constants._PUB_KEY_CRED_PARAMS)
        }
        return false
    }

    private func isFidoAuthentication() -> Bool {
        if let action = value[Constants.ACTION] as? String, action == Constants.WEBAUTHN_AUTHENTICATION {
            return true
        }
        if let type = value[Constants.TYPE] as? String, type == Constants.WEB_AUTHN {
            return value.keys.contains(Constants.ALLOW_CREDENTIALS) || value.keys.contains(Constants._ALLOW_CREDENTIALS)
        }
        return false
    }

    private func isProtectInitialize() -> Bool {
        guard let type = value[Constants.TYPE] as? String, type == Constants.PING_ONE_PROTECT,
              let action = value[Constants.ACTION] as? String, action == Constants.PROTECT_INITIALIZE else {
            return false
        }
        return true
    }

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

