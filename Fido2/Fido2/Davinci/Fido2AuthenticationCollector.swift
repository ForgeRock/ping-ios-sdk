//
//  Fido2AuthenticationCollector.swift
//  Fido2
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

public class Fido2AuthenticationCollector: AbstractFido2Collector, @unchecked Sendable {
    
    public var publicKeyCredentialRequestOptions: [String: Any] = [:]
    public var assertionValue: [String: Any]?
    
    required public init(with json: [String : Any]) {
        super.init(with: json)
        logger?.d("Initializing FIDO2 authentication collector")
        guard let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS] as? [String: Any] else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS)", error: nil)
            return
        }
        self.publicKeyCredentialRequestOptions = self.transform(options)
        logger?.d("FIDO2 authentication collector initialized with request options")
    }
        
    override public func payload() -> [String: Any]? {
        guard let assertionValue = assertionValue else {
            logger?.d("No assertion value available, returning null payload")
            return nil
        }
        logger?.d("Returning assertion payload for FIDO2 authentication")
        return [FidoConstants.FIELD_ASSERTION_VALUE: assertionValue]
    }
    
    public func authenticate(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        logger?.d("Starting FIDO2 authentication")

        guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else {
            completion(.failure(FidoError.invalidWindow))
            return
        }

        Fido2.shared.authenticate(options: publicKeyCredentialRequestOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO2 authentication successful, building assertionValue object...")
                
                let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data ?? Data()
                let signatureInt8 = signatureData.bytesArray.map { Int8(bitPattern: $0) }
                let signature = convertInt8ArrToStr(signatureInt8)
                
                let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data ?? Data()
                let clientDataJSON = String(decoding: clientData, as: UTF8.self)
                
                let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data ?? Data()
                let authenticatorDataInt8 = authenticatorData.bytesArray.map { Int8(bitPattern: $0) }
                let authenticatorDataString = convertInt8ArrToStr(authenticatorDataInt8)
                
                let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data ?? Data()
                let credID = base64ToBase64url(base64: credIDData.base64EncodedString())
                
                let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data ?? Data()
                let userIDString = String(decoding: userHandleData, as: UTF8.self)
                
                // Builds the assertionValue with all the correct encodings
                let assertionValue: [String: Any] = [
                    // ✅ `id` is Base64URL
                    FidoConstants.FIELD_ID: credIDData.base64urlEncodedString(),
                    // ✅ `rawId` is standard Base64
                    FidoConstants.FIELD_RAW_ID: credIDData.base64EncodedString(),
                    FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: "platform",
                    FidoConstants.FIELD_TYPE: FidoConstants.FIELD_PUB_KEY,
                    FidoConstants.FIELD_RESPONSE: [
                        // ✅ All nested fields are correctly Base64URL encoded
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
                self.logger?.e("FIDO2 authentication failed", error: error)
                completion(.failure(error))
            }
        }
    }
    
    private func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO2 authentication request options")
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
        
        logger?.d("FIDO2 authentication request options transformed successfully")
        return output
    }
}
