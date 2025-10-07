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
        if let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS] as? [String: Any] {
            publicKeyCredentialCreationOptions = transform(options)
        } else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS)", error: nil)
        }
        logger?.d("FIDO2 registration collector initialized with creation options")
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
                self.logger?.d("FIDO2 registration successful")
                self.attestationValue = response
                completion(.success(response))
            case .failure(let error):
                self.logger?.e("FIDO2 registration failed", error: error)
                completion(.failure(error))
            }
        }
    }
    
    private func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO2 registration creation options")
        var output = input
        
        if let user = output[FidoConstants.FIELD_USER] as? [String: Any],
           let userId = user[FidoConstants.FIELD_ID] as? [Int] {
            var newUser = user
            let data = Data(userId.map { UInt8(bitPattern: Int8($0)) })
            newUser[FidoConstants.FIELD_ID] = data.base64EncodedString()
            output[FidoConstants.FIELD_USER] = newUser
        }
        
        if let challenge = output[FidoConstants.FIELD_CHALLENGE] as? [Int] {
            let data = Data(challenge.map { UInt8(bitPattern: Int8($0)) })
            output[FidoConstants.FIELD_CHALLENGE] = data.base64EncodedString()
        }
        
        logger?.d("FIDO2 registration creation options transformed successfully")
        return output
    }
}
