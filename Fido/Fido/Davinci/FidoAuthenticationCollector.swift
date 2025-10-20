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
import PingDavinci
import PingLogger
import UIKit
import AuthenticationServices

/// A collector for Fido authentication within a DaVinci flow.
public class FidoAuthenticationCollector: AbstractFidoCollector, @unchecked Sendable {
    
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
    
    /// Initiates the FIDO authentication process.
    ///
    /// This method uses the `Fido.shared.authenticate` method to perform the authentication ceremony.
    /// On success, it constructs the `assertionValue` and calls the completion handler.
    /// - Parameter completion: A closure to be called with the result of the authentication.
    public func authenticate(window: ASPresentationAnchor, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        logger?.d("Starting FIDO authentication")
        
        fido.authenticate(options: publicKeyCredentialRequestOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO authentication successful, building assertionValue object...")
                
                guard let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data,
                      let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                      let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data,
                      let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                      let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data else {
                    let error = FidoError.invalidResponse
                    self.logger?.e(error.localizedDescription, error: error)
                    completion(.failure(error))
                    return
                }
                
                let userIDString = String(decoding: userHandleData, as: UTF8.self)
                // Construct the assertionValue payload in the format expected by the server.
                let assertionValue: [String: Any] = [
                    // `id` is Base64URL
                    FidoConstants.FIELD_ID: credIDData.base64urlEncodedString(),
                    // `rawId` is standard Base64
                    FidoConstants.FIELD_RAW_ID: credIDData.base64EncodedString(),
                    FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: "platform",
                    FidoConstants.FIELD_TYPE: FidoConstants.FIELD_PUB_KEY,
                    FidoConstants.FIELD_RESPONSE: [
                        FidoConstants.FIELD_AUTHENTICATOR_DATA: authenticatorData.base64urlEncodedString(),
                        FidoConstants.FIELD_CLIENT_DATA_JSON: clientData.base64urlEncodedString(),
                        FidoConstants.FIELD_SIGNATURE: signatureData.base64urlEncodedString(),
                        FidoConstants.FIELD_USER_HANDLE: userIDString
                    ]
                ]
                
                self.logger?.d("assertionValue object created successfully")
                self.assertionValue = assertionValue
                completion(.success(assertionValue))
                
            case .failure(let error):
                self.logger?.e("FIDO authentication failed", error: error)
                completion(.failure(error))
            }
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

