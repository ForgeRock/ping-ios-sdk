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
    
    /// Initiates the FIDO authentication process using async/await.
    ///
    /// - Parameter window: The `ASPresentationAnchor` to present the FIDO UI.
    /// - Throws: An error if the authentication process fails.
    @MainActor
    public func authenticate(window: ASPresentationAnchor) async -> Result<[String: Any], Error> {
        logger?.d("Starting FIDO authentication (async Result)")
        
        do {
            // 1. Wrap the closure-based fido.authenticate in a continuation
            //    This still throws internally within the 'do' block if the continuation resumes with an error.
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                // Assuming 'fido' instance is accessible
                fido.authenticate(options: publicKeyCredentialRequestOptions, window: window) { result in
                    continuation.resume(with: result) // Resume with the Result<[String: Any], Error>
                }
            }
            
            // 2. Handle the successful response data extraction
            self.logger?.d("FIDO authentication successful, processing response...")
            
            guard let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data,
                  let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                  let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data,
                  let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                  let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data else {
                
                let error = FidoError.invalidResponse // Define your error type
                self.logger?.e(error.localizedDescription, error: error)
                self.handleError(error: error) // Keep existing error handling side-effect
                return .failure(error) // Return failure
            }
            
            // 3. Process data and set callback value (side effect)
            let legacyData = [
                String(decoding: clientData, as: UTF8.self),
                convertInt8ArrToStr(authenticatorData.bytesArray.map { Int8(bitPattern: $0) }),
                convertInt8ArrToStr(signatureData.bytesArray.map { Int8(bitPattern: $0) }),
                base64ToBase64url(base64: credIDData.base64EncodedString()),
                String(decoding: userHandleData, as: UTF8.self)
            ].joined(separator: FidoConstants.DATA_SEPARATOR)
            
            let callbackValue: String
            if self.supportsJsonResponse {
                let jsonResponse: [String: Any] = [
                    FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: FidoConstants.AUTHENTICATOR_PLATFORM,
                    FidoConstants.FIELD_LEGACY_DATA: legacyData
                ]
                // Safely create JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    callbackValue = jsonString
                } else {
                    // Handle potential JSON serialization error if needed
                    callbackValue = ""
                    logger?.w("Failed to serialize FIDO JSON response", error: nil)
                }
            } else {
                callbackValue = legacyData
            }
            
            self.logger?.d("Setting authentication callback value")
            self.valueCallback(value: callbackValue) // Perform side effect
            
            // 4. Return success with the original response dictionary
            return .success(response)
            
        } catch {
            // 5. Handle any error caught from the continuation
            self.logger?.e("FIDO authentication failed", error: error)
            self.handleError(error: error) // Keep existing error handling side-effect
            return .failure(error) // Return failure
        }
    }
    
    // MARK: - Private Transform
    
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
