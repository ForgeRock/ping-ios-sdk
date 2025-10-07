//
//  Fido2RegistrationCallback.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
import AuthenticationServices
import PingLogger

/// A callback for handling FIDO2 registration in a PingOne Journey.
public class Fido2RegistrationCallback: Fido2Callback, @unchecked Sendable {
    
    /// The `PublicKeyCredentialCreationOptions` received from the server for FIDO2 registration.
    public var publicKeyCredentialCreationOptions: [String: Any] = [:]
    
    private var supportsJsonResponse: Bool = false
    
    /// Initializes the callback with the provided JSON data.
    /// - Parameter json: The JSON data used to initialize the callback.
    /// - Returns: The initialized callback instance.
    public override func initValue(name: String, value: Any) {
        if name == FidoConstants.FIELD_DATA, let data = value as? [String: Any] {
            logger?.d("Processing FIDO2 authentication data")
            supportsJsonResponse = data[FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE] as? Bool ?? false
            publicKeyCredentialCreationOptions = transform(data)
            logger?.d("FIDO2 authentication callback initialized successfully")
        }
    }
    
    /// Initiates the FIDO2 registration process.
    /// - Parameters:
    ///  - deviceName: An optional name for the device being registered.
    ///  - window: The `ASPresentationAnchor` to present the FIDO2 UI.
    ///  - completion: A closure that is called upon completion of the registration process, with
    ///              a `Result` containing either the registration response or an error.
    public func register(deviceName: String? = nil, window: ASPresentationAnchor, completion: @escaping (Error?) -> Void) {
        logger?.d("Starting FIDO2 registration with device name: \(deviceName ?? "nil")")
        
        Fido2.shared.register(options: publicKeyCredentialCreationOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO2 registration successful")
                
                let clientDataJSON = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? String ?? ""
                let attestationObject = response[FidoConstants.FIELD_ATTESTATION_OBJECT] as? String ?? ""
                let rawId = response[FidoConstants.FIELD_RAW_ID] as? String ?? ""
                
                var data = [
                    clientDataJSON,
                    attestationObject,
                    rawId
                ].joined(separator: FidoConstants.DATA_SEPARATOR)
                
                if let deviceName = deviceName {
                    data += "\(FidoConstants.DATA_SEPARATOR)\(deviceName)"
                }
                
                let callbackValue: String
                if self.supportsJsonResponse {
                    let jsonResponse: [String: Any] = [
                        FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: FidoConstants.AUTHENTICATOR_PLATFORM,
                        FidoConstants.FIELD_LEGACY_DATA: data
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        callbackValue = jsonString
                    } else {
                        callbackValue = ""
                    }
                } else {
                    callbackValue = data
                }
                
                self.logger?.d("Setting registration callback value")
                self.valueCallback(value: callbackValue)
                completion(nil)
            case .failure(let error):
                self.logger?.e("FIDO2 registration failed", error: error)
                self.handleError(error: error)
                completion(error)
            }
        }
    }
    
    /// Transforms the input dictionary to match the expected format for FIDO2 registration.
    /// - Parameter input: The input dictionary containing FIDO2 registration options.
    /// - Returns: A transformed dictionary suitable for FIDO2 registration.
    func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO2 registration creation options")
        var output: [String: Any] = [:]

        if let challenge = input[FidoConstants.FIELD_CHALLENGE] as? String {
            output[FidoConstants.FIELD_CHALLENGE] = challenge
        }

        if let timeoutStr = input[FidoConstants.FIELD_TIMEOUT] as? String, let timeout = Int(timeoutStr) {
            output[FidoConstants.FIELD_TIMEOUT] = timeout
        } else {
            output[FidoConstants.FIELD_TIMEOUT] = FidoConstants.DEFAULT_TIMEOUT
        }

        if let attestation = input[FidoConstants.FIELD_ATTESTATION_PREFERENCE] as? String {
            output[FidoConstants.FIELD_ATTESTATION] = attestation
        } else {
            output[FidoConstants.FIELD_ATTESTATION] = FidoConstants.DEFAULT_ATTESTATION
        }

        var rp: [String: Any] = [:]
        if let rpName = input[FidoConstants.FIELD_RELYING_PARTY_NAME] as? String {
            rp[FidoConstants.FIELD_NAME] = rpName
        }
        if let rpId = input[FidoConstants.FIELD_RELYING_PARTY_ID_INTERNAL] as? String {
            rp[FidoConstants.FIELD_ID] = rpId
        } else {
            rp[FidoConstants.FIELD_ID] = FidoConstants.DEFAULT_RELYING_PARTY_ID
        }
        output[FidoConstants.FIELD_RP] = rp

        var user: [String: Any] = [:]
        if let userId = input[FidoConstants.FIELD_USER_ID] as? String {
            user[FidoConstants.FIELD_ID] = userId
        }
        if let userName = input[FidoConstants.FIELD_USER_NAME] as? String {
            user[FidoConstants.FIELD_NAME] = userName
        }
        if let displayName = input[FidoConstants.FIELD_DISPLAY_NAME] as? String {
            user[FidoConstants.FIELD_DISPLAY_NAME] = displayName
        }
        output[FidoConstants.FIELD_USER] = user

        if let pubKeyCredParams = input[FidoConstants.FIELD_PUB_KEY_CRED_PARAMS_INTERNAL] as? [[String: Any]] {
            output[FidoConstants.FIELD_PUB_KEY_CRED_PARAMS] = pubKeyCredParams.map { param -> [String: Any] in
                var newParam: [String: Any] = [:]
                if let type = param[FidoConstants.FIELD_TYPE] as? String {
                    newParam[FidoConstants.FIELD_TYPE] = type
                }
                if let alg = param[FidoConstants.FIELD_ALG] as? Int64 {
                    newParam[FidoConstants.FIELD_ALG] = alg
                }
                return newParam
            }
        }

        if let excludeCredentials = input[FidoConstants.FIELD_EXCLUDE_CREDENTIALS_INTERNAL] as? [[String: Any]] {
            output[FidoConstants.FIELD_EXCLUDE_CREDENTIALS] = excludeCredentials.map { credential -> [String: Any] in
                var newCredential: [String: Any] = [:]
                if let type = credential[FidoConstants.FIELD_TYPE] as? String {
                    newCredential[FidoConstants.FIELD_TYPE] = type
                }
                if let idArray = credential[FidoConstants.FIELD_ID] as? [Int] {
                    let data = Data(idArray.map { UInt8($0) })
                    newCredential[FidoConstants.FIELD_ID] = data.base64EncodedString()
                }
                return newCredential
            }
        }

        if let authSelection = input[FidoConstants.FIELD_AUTHENTICATOR_SELECTION_INTERNAL] as? [String: Any] {
            var newAuthSelection: [String: Any] = [:]
            if let authenticatorAttachment = authSelection[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String {
                newAuthSelection[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] = authenticatorAttachment
            }
            if let requireResidentKey = authSelection[FidoConstants.FIELD_REQUIRE_RESIDENT_KEY] as? Bool {
                newAuthSelection[FidoConstants.FIELD_REQUIRE_RESIDENT_KEY] = requireResidentKey
                newAuthSelection[FidoConstants.FIELD_RESIDENT_KEY] = requireResidentKey ? FidoConstants.DEFAULT_RESIDENT_KEY_REQUIRED : FidoConstants.RESIDENT_KEY_DISCOURAGED
            }
            if let residentKey = authSelection[FidoConstants.FIELD_RESIDENT_KEY] as? String {
                newAuthSelection[FidoConstants.FIELD_RESIDENT_KEY] = residentKey
            }
            if let userVerification = authSelection[FidoConstants.FIELD_USER_VERIFICATION] as? String {
                newAuthSelection[FidoConstants.FIELD_USER_VERIFICATION] = userVerification
            }
            output[FidoConstants.FIELD_AUTHENTICATOR_SELECTION] = newAuthSelection
        }

        return output
    }
}
