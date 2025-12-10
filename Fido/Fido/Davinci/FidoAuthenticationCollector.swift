//
//  FidoAuthenticationCollector.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingDavinciPlugin
import PingLogger
import UIKit
import AuthenticationServices
import PingOrchestrate
import PingCommons

/// A collector for FIDO authentication within a DaVinci flow.
public class FidoAuthenticationCollector: AbstractFidoCollector, Closeable, @unchecked Sendable {
    
    /// Resets the collector's state by clearing the assertion value.
    public func close() {
        self.assertionValue = nil
    }
    
    /// The public key credential request options provided by the server.
    public var publicKeyCredentialRequestOptions: [String: Any] = [:]
    /// The assertion value constructed after a successful authentication. This value is sent to the server.
    public var assertionValue: [String: Any]?
    
    /// Initializes a new Fido authentication collector.
    ///
    /// - Parameter json: The JSON payload from the server that includes the Fido authentication options.
    /// - Throws: An error if the required `publicKeyCredentialRequestOptions` parameter is missing from the JSON.
    required public init(with json: [String : Any]) {
        super.init(with: json)
        logger?.d("Initializing Fido authentication collector")
        guard let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS] as? [String: Any] else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS)", error: nil)
            return
        }
        self.publicKeyCredentialRequestOptions = self.transform(options)
        logger?.d("Fido authentication collector initialized with request options")
    }
    
    /// The payload to be sent to the DaVinci server.
    ///
    /// - Returns: A dictionary containing the assertion value, or `nil` if authentication has not been completed.
    override public func payload() -> [String: Any]? {
        guard let assertionValue = assertionValue else {
            logger?.d("No assertion value available, returning null payload")
            return nil
        }
        logger?.d("Returning assertion payload for Fido authentication")
        return [FidoConstants.FIELD_ASSERTION_VALUE: assertionValue]
    }
    
    
    /// Initiates the FIDO authentication process using async/await.
    ///
    /// This method uses the `fido.authenticate` method to perform the authentication ceremony.
    /// On success, it constructs and stores the `assertionValue`, then returns it.
    /// - Parameter window: The `ASPresentationAnchor` to present the FIDO UI.
    /// - Returns: A dictionary representing the `assertionValue`.
    /// - Throws: An error if the authentication process fails or the response is invalid.
    @MainActor
    public func authenticate(window: ASPresentationAnchor) async -> Result<[String: Any], Error> {
        logger?.d("Starting FIDO authentication (async Result)")
        
        do {
            // 1. Wrap the closure-based fido.authenticate in a continuation
            //    This still throws internally within the 'do' block if the continuation resumes with an error.
            let response: [String: Any] = try await withUnsafeThrowingContinuation { continuation in
                // Assuming 'fido' instance is accessible
                fido.authenticate(options: publicKeyCredentialRequestOptions, window: window) { [continuation] result in
                    Task {
                        await MainActor.run {
                            continuation.resume(with: result) // Resume with the Result<[String: Any>, Error>
                        }
                    }
                }
            }
            
            // 2. Process the successful response data extraction
            logger?.d("FIDO authentication successful, building assertionValue object...")
            
            guard let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data,
                  let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                  let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data,
                  let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                  let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data else {
                
                let error = FidoError.invalidResponse
                logger?.e(error.localizedDescription, error: error)
                let transformedError = self.handleError(error: error)
                return .failure(transformedError) // Return failure with transformed error
            }
            
            // 3. Construct the assertionValue payload
            let userIDString = String(decoding: userHandleData, as: UTF8.self)
            let newAssertionValue: [String: Any] = [
                FidoConstants.FIELD_ID: credIDData.base64URLEncodedString(),
                FidoConstants.FIELD_RAW_ID: credIDData.base64EncodedString(),
                FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: "platform",
                FidoConstants.FIELD_TYPE: FidoConstants.FIELD_PUB_KEY,
                FidoConstants.FIELD_RESPONSE: [
                    FidoConstants.FIELD_AUTHENTICATOR_DATA: authenticatorData.base64URLEncodedString(),
                    FidoConstants.FIELD_CLIENT_DATA_JSON: clientData.base64URLEncodedString(),
                    FidoConstants.FIELD_SIGNATURE: signatureData.base64URLEncodedString(),
                    FidoConstants.FIELD_USER_HANDLE: userIDString
                ]
            ]
            
            logger?.d("assertionValue object created successfully")
            self.assertionValue = newAssertionValue // Store the value (side effect)
            
            // 4. Return success with the constructed assertionValue
            return .success(newAssertionValue)
            
        } catch {
            // 5. Handle any error caught from the continuation
            logger?.e("FIDO authentication failed", error: error)
            let transformedError = self.handleError(error: error)
            return .failure(transformedError) // Return failure with transformed error
        }
    }
    
    /// Transforms the FIDO authentication request options from the server to the format expected by the `ASAuthorization` framework.
    ///
    /// This involves converting byte arrays for `challenge` and `allowCredentials` IDs to Base64 encoded strings.
    /// - Parameter input: The dictionary of options received from the server.
    /// - Returns: A transformed dictionary of options.
    private func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO authentication request options")
        var output = input
        
        if let challenge = output[FidoConstants.FIELD_CHALLENGE] as? [Int] {
            let data = Data(challenge.map { UInt8(bitPattern: Int8($0)) })
            output[FidoConstants.FIELD_CHALLENGE] = data.base64EncodedString()
        }
        
        // Handle timeout field
        if let timeout = output[FidoConstants.FIELD_TIMEOUT] as? Int {
            output[FidoConstants.FIELD_TIMEOUT] = timeout
        }
        
        if let allowCredentials = output[FidoConstants.FIELD_ALLOW_CREDENTIALS] as? [[String: Any]] {
            let updatedCredentials = allowCredentials.map { credential -> [String: Any] in
                var newCredential = credential
                if let id = newCredential[FidoConstants.FIELD_ID] as? [Int] {
                    let data = Data(id.map { UInt8(bitPattern: Int8($0)) })
                    newCredential[FidoConstants.FIELD_ID] = data.base64EncodedString()
                }
                return newCredential
            }
            output[FidoConstants.FIELD_ALLOW_CREDENTIALS] = updatedCredentials
        }
        
        logger?.d("FIDO authentication request options transformed successfully")
        return output
    }
}

