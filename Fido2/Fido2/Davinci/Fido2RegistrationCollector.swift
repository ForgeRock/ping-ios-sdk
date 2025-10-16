//
//  Fido2RegistrationCollector.swift
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

public class Fido2RegistrationCollector: AbstractFido2Collector, @unchecked Sendable {
    
    public var publicKeyCredentialCreationOptions: [String: Any] = [:]
    public var attestationValue: [String: Any]?
    
    required public init(with json: [String : Any]) {
        super.init(with: json)
        logger?.d("Initializing FIDO2 registration collector")
        guard let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS] as? [String: Any] else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS)", error: nil)
            return
        }
        self.publicKeyCredentialCreationOptions = self.transform(options)
        logger?.d("FIDO2 registration collector initialized with creation options")
    }
    
    private func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO2 registration creation options")
        var output = input
        
        if let user = output[FidoConstants.FIELD_USER] as? [String: Any] {
            logger?.d("User: \(user)")
            if let userId = user[FidoConstants.FIELD_ID] as? [Int] {
                var newUser = user
                let data = Data(userId.map { UInt8(bitPattern: Int8($0)) })
                newUser[FidoConstants.FIELD_ID] = data.base64EncodedString()
                output[FidoConstants.FIELD_USER] = newUser
            }
        }
        
        if let challenge = output[FidoConstants.FIELD_CHALLENGE] as? [Int] {
            logger?.d("Challenge: \(challenge)")
            let data = Data(challenge.map { UInt8(bitPattern: Int8($0)) })
            output[FidoConstants.FIELD_CHALLENGE] = data.base64EncodedString()
        }
        
        if let excludeCredentials = output[FidoConstants.FIELD_EXCLUDE_CREDENTIALS] as? [[String: Any]] {
            logger?.d("Exclude credentials: \(excludeCredentials)")
            let updatedCredentials = excludeCredentials.map { credential -> [String: Any] in
                var newCredential = credential
                if let id = newCredential[FidoConstants.FIELD_ID] as? [Int] {
                    let data = Data(id.map { UInt8(bitPattern: Int8($0)) })
                    newCredential[FidoConstants.FIELD_ID] = data.base64EncodedString()
                }
                return newCredential
            }
            output[FidoConstants.FIELD_EXCLUDE_CREDENTIALS] = updatedCredentials
        }
        
        logger?.d("FIDO2 registration creation options transformed successfully")
        return output
    }
    
    override public func payload() -> [String: Any]? {
        guard let attestationValue = attestationValue else {
            logger?.d("No attestation value available, returning null payload")
            return nil
        }
        logger?.d("Returning attestation payload for FIDO2 registration")
        return [FidoConstants.FIELD_ATTESTATION_VALUE: attestationValue]
    }
    
    public func register(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        logger?.d("Starting FIDO2 registration")

        guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else {
            completion(.failure(FidoError.invalidWindow))
            return
        }

        Fido2.shared.register(options: publicKeyCredentialCreationOptions, window: window) { result in
            switch result {
            case .success(let response):
                self.logger?.d("FIDO2 registration successful, building attestationValue object...")

                // ✅ FIX 1: Cast to `Data`, not `String`. FIDO2 libraries return raw binary data.
                guard let rawIdData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                      let clientDataJSONData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                      let attestationObjectData = response[FidoConstants.FIELD_ATTESTATION_OBJECT] as? Data else {
                    let error = FidoError.invalidResponse
                    self.logger?.e(error.localizedDescription, error: error)
                    completion(.failure(error))
                    return
                }
                
                
                // This is likely static for registrations from this device.
                let authenticatorAttachment = "platform"

                // ✅ FIX 2: Build the dictionary using the correct encoding methods on the `Data` objects.
                let attestationValue: [String: Any] = [
                    // `id` MUST be Base64URL encoded.
                    FidoConstants.FIELD_ID: rawIdData.base64urlEncodedString(),
                    
                    FidoConstants.FIELD_TYPE: FidoConstants.FIELD_PUB_KEY,
                    
                    // `rawId` MUST be standard Base64 encoded.
                    FidoConstants.FIELD_RAW_ID: rawIdData.base64EncodedString(),
                    
                    FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: authenticatorAttachment,
                    
                    FidoConstants.FIELD_RESPONSE: [
                        // These values MUST be Base64URL encoded.
                        FidoConstants.FIELD_CLIENT_DATA_JSON: clientDataJSONData.base64urlEncodedString(),
                        FidoConstants.FIELD_ATTESTATION_OBJECT: attestationObjectData.base64urlEncodedString()
                    ]
                ]
                
                self.logger?.d("attestationValue object created successfully")

                // 3. Return the fully formed 'attestationValue' object.
                self.attestationValue = attestationValue
                completion(.success(attestationValue))
                
            case .failure(let error):
                self.logger?.e("FIDO2 registration failed", error: error)
                completion(.failure(error))
            }
        }
    }
}
