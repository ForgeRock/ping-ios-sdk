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
    
    /// A flag indicating whether the server supports a JSON response format.
    private var supportsJsonResponse: Bool = false
    
    /// Initializes the callback's properties with values from the JSON payload.
    ///
    /// - Parameters:
    ///   - name: The name of the property to initialize.
    ///   - value: The value of the property.
    public override func initValue(name: String, value: Any) {
        if name == FidoConstants.FIELD_DATA, let data = value as? [String: Any] {
            logger?.d("Processing FIDO2 registration data")
            supportsJsonResponse = data[FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE] as? Bool ?? false
            publicKeyCredentialCreationOptions = transform(data)
            logger?.d("FIDO2 registration callback initialized successfully")
        }
    }
    
    /// Initiates the FIDO2 registration process.
    ///
    /// - Parameters:
    ///  - deviceName: An optional name for the device being registered.
    ///  - window: The `ASPresentationAnchor` to present the FIDO2 UI.
    ///  - completion: A closure that is called upon completion of the registration process.
    public func register(deviceName: String? = nil, window: ASPresentationAnchor, completion: @escaping (Error?) -> Void) {
        logger?.d("Starting FIDO2 registration with device name: \(deviceName ?? "nil")")
        
        Fido2.shared.register(options: publicKeyCredentialCreationOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO2 registration successful")
                guard let rawAttestationObject = response[FidoConstants.FIELD_ATTESTATION_OBJECT] as? Data,
                      let rawClientDataJSON = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                      let rawIdData = response[FidoConstants.FIELD_RAW_ID] as? Data else {
                    let error = FidoError.invalidResponse
                    self.logger?.e(error.localizedDescription, error: error)
                    self.handleError(error: error)
                    completion(error)
                    return
                }
                
                // For older servers, a concatenated string is sent.
                let legacyData = [
                    String(decoding: rawClientDataJSON, as: UTF8.self),
                    convertInt8ArrToStr(rawAttestationObject.bytesArray.map { Int8(bitPattern: $0) }),
                    base64ToBase64url(base64: rawIdData.base64EncodedString())
                ].joined(separator: FidoConstants.DATA_SEPARATOR)
                
                var finalData = legacyData
                if let deviceName = deviceName {
                    finalData += "\(FidoConstants.DATA_SEPARATOR)\(deviceName)"
                }
                
                let callbackValue: String
                if self.supportsJsonResponse {
                    // For newer servers, a JSON object is sent.
                    let jsonResponse: [String: Any] = [
                        FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: FidoConstants.AUTHENTICATOR_PLATFORM,
                        FidoConstants.FIELD_LEGACY_DATA: finalData
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        callbackValue = jsonString
                    } else {
                        callbackValue = ""
                    }
                } else {
                    callbackValue = finalData
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
    
    /// Transforms the input dictionary from the server to the format expected by the FIDO2 client.
    ///
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
                if authSelection[FidoConstants.FIELD_REQUIRE_RESIDENT_KEY] as? Bool == nil {
                    if residentKey == FidoConstants.RESIDENT_KEY_DISCOURAGED {
                        newAuthSelection[FidoConstants.FIELD_REQUIRE_RESIDENT_KEY] = false
                    } else {
                        newAuthSelection[FidoConstants.FIELD_REQUIRE_RESIDENT_KEY] = true
                    }
                }
                
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
