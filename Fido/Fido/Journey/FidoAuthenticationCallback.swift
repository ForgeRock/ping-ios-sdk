//
//  FidoAuthenticationCallback.swift
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

/// A callback for handling FIDO authentication in a PingOne Journey.
public class FidoAuthenticationCallback: FidoCallback, @unchecked Sendable {
    
    /// The `PublicKeyCredentialRequestOptions` received from the server for FIDO authentication.
    public var publicKeyCredentialRequestOptions: [String: Any] = [:]
    
    /// A flag indicating whether the server supports a JSON response format.
    private var supportsJsonResponse: Bool = false
    
    /// Initializes the callback's properties with values from the JSON payload.
    ///
    /// - Parameters:
    ///   - name: The name of the property to initialize.
    ///   - value: The value of the property.
    public override func initValue(name: String, value: Any) {
        if name == FidoConstants.FIELD_DATA, let data = value as? [String: Any] {
            logger?.d("Processing FIDO authentication data")
            supportsJsonResponse = data[FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE] as? Bool ?? false
            publicKeyCredentialRequestOptions = transform(data)
            logger?.d("FIDO authentication callback initialized successfully")
        }
    }
    
    /// Initiates the FIDO authentication process.
    ///
    /// - Parameters:
    ///  - window: The `ASPresentationAnchor` to present the FIDO UI.
    ///  - completion: A closure that is called upon completion of the authentication process.
    public func authenticate(window: ASPresentationAnchor, completion: @escaping (Error?) -> Void) {
        logger?.d("Starting FIDO authentication")
        
        fido.authenticate(options: publicKeyCredentialRequestOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO authentication successful")
                
                guard let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data,
                      let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                      let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data,
                      let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                      let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data else {
                    let error = FidoError.invalidResponse
                    self.logger?.e(error.localizedDescription, error: error)
                    self.handleError(error: error)
                    completion(error)
                    return
                }
                
                // For older servers, a concatenated string is sent.
                let legacyData = [
                    String(decoding: clientData, as: UTF8.self),
                    convertInt8ArrToStr(authenticatorData.bytesArray.map { Int8(bitPattern: $0) }),
                    convertInt8ArrToStr(signatureData.bytesArray.map { Int8(bitPattern: $0) }),
                    base64ToBase64url(base64: credIDData.base64EncodedString()),
                    String(decoding: userHandleData, as: UTF8.self)
                ].joined(separator: FidoConstants.DATA_SEPARATOR)
                
                let callbackValue: String
                if self.supportsJsonResponse {
                    // For newer servers, a JSON object is sent.
                    let jsonResponse: [String: Any] = [
                        FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: FidoConstants.AUTHENTICATOR_PLATFORM,
                        FidoConstants.FIELD_LEGACY_DATA: legacyData
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        callbackValue = jsonString
                    } else {
                        callbackValue = ""
                    }
                } else {
                    callbackValue = legacyData
                }
                
                self.logger?.d("Setting authentication callback value")
                self.valueCallback(value: callbackValue)
                completion(nil)
            case .failure(let error):
                self.logger?.e("FIDO authentication failed", error: error)
                self.handleError(error: error)
                completion(error)
            }
        }
    }
    
    /// Transforms the input dictionary from the server to the format expected by the FIDO client.
    ///
    /// - Parameter input: The input dictionary containing FIDO authentication options.
    /// - Returns: A transformed dictionary suitable for FIDO authentication.
    func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO authentication request options")
        var output: [String: Any] = [:]

        if let challenge = input[FidoConstants.FIELD_CHALLENGE] as? String {
            output[FidoConstants.FIELD_CHALLENGE] = challenge
        }

        if let timeoutStr = input[FidoConstants.FIELD_TIMEOUT] as? String, let timeout = Int(timeoutStr) {
            output[FidoConstants.FIELD_TIMEOUT] = timeout
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
