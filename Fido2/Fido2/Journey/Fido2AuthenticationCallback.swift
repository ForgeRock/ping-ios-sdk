//
//  Fido2AuthenticationCallback.swift
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

/// A callback for handling FIDO2 authentication in a PingOne Journey.
public class Fido2AuthenticationCallback: Fido2Callback, @unchecked Sendable {
    
    /// The `PublicKeyCredentialRequestOptions` received from the server for FIDO2 authentication.
    public var publicKeyCredentialRequestOptions: [String: Any] = [:]
    
    private var supportsJsonResponse: Bool = false
    
    /// Initializes the callback with the provided JSON data.
    /// - Parameter json: The JSON data used to initialize the callback.
    /// - Returns: The initialized callback instance.
    public override func initValue(name: String, value: Any) {
        if name == FidoConstants.FIELD_DATA, let data = value as? [String: Any] {
            logger?.d("Processing FIDO2 authentication data")
            supportsJsonResponse = data[FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE] as? Bool ?? false
            publicKeyCredentialRequestOptions = transform(data)
            logger?.d("FIDO2 authentication callback initialized successfully")
        }
    }
    
    /// Initiates the FIDO2 authentication process.
    /// - Parameters:
    ///  - window: The `ASPresentationAnchor` to present the FIDO2 UI.
    ///  - completion: A closure that is called upon completion of the authentication process, with
    ///              a `Result` containing either the authentication response or an error.
    public func authenticate(window: ASPresentationAnchor, completion: @escaping (Error?) -> Void) {
        logger?.d("Starting FIDO2 authentication")
        
        Fido2.shared.authenticate(options: publicKeyCredentialRequestOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO2 authentication successful")
                
                let clientDataJSON = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? String ?? ""
                let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? String ?? ""
                let signature = response[FidoConstants.FIELD_SIGNATURE] as? String ?? ""
                let rawId = response[FidoConstants.FIELD_RAW_ID] as? String ?? ""
                let userHandle = response[FidoConstants.FIELD_USER_HANDLE] as? String ?? ""
                
                let data = [
                    clientDataJSON,
                    authenticatorData,
                    signature,
                    rawId,
                    userHandle
                ].joined(separator: FidoConstants.DATA_SEPARATOR)
                
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
                
                self.logger?.d("Setting authentication callback value")
                self.valueCallback(value: callbackValue)
                completion(nil)
            case .failure(let error):
                self.logger?.e("FIDO2 authentication failed", error: error)
                self.handleError(error: error)
                completion(error)
            }
        }
    }
    
    /// Transforms the input dictionary to match the expected format for FIDO2 authentication.
    /// - Parameter input: The input dictionary containing FIDO2 authentication options.
    /// - Returns: A transformed dictionary suitable for FIDO2 authentication.
    func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO2 authentication request options")
        var output: [String: Any] = [:]

        if let challenge = input[FidoConstants.FIELD_CHALLENGE] as? String {
            output[FidoConstants.FIELD_CHALLENGE] = challenge
        }

        if let timeoutStr = input[FidoConstants.FIELD_TIMEOUT] as? String, let timeout = Int(timeoutStr) {
            output[FidoConstants.FIELD_TIMEOUT] = timeout
        } else {
            output[FidoConstants.FIELD_TIMEOUT] = FidoConstants.DEFAULT_TIMEOUT
        }

        if let userVerification = input[FidoConstants.FIELD_USER_VERIFICATION] as? String {
            output[FidoConstants.FIELD_USER_VERIFICATION] = userVerification
        } else {
            output[FidoConstants.FIELD_USER_VERIFICATION] = FidoConstants.DEFAULT_USER_VERIFICATION
        }

        if let rpId = input[FidoConstants.FIELD_RELYING_PARTY_ID_INTERNAL] as? String {
            output[FidoConstants.FIELD_RP_ID] = rpId
        }

        if let allowCredentials = input[FidoConstants.FIELD_ALLOW_CREDENTIALS_INTERNAL] as? [[String: Any]] {
            output[FidoConstants.FIELD_ALLOW_CREDENTIALS] = allowCredentials.map { credential -> [String: Any] in
                var newCredential: [String: Any] = [:]
                if let type = credential[FidoConstants.FIELD_TYPE] as? String {
                    newCredential[FidoConstants.FIELD_TYPE] = type
                }
                if let idArray = credential[FidoConstants.FIELD_ID] as? [Int] {
                    let data = Data(idArray.map { UInt8(bitPattern: Int8($0)) })
                    newCredential[FidoConstants.FIELD_ID] = data.base64EncodedString()
                }
                return newCredential
            }
        }

        return output
    }
}
