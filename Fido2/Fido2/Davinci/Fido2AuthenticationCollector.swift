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
        if let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS] as? [String: Any] {
            publicKeyCredentialRequestOptions = transform(options)
        } else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS)", error: nil)
        }
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
                self.logger?.d("FIDO2 authentication successful")
                self.assertionValue = response
                completion(.success(response))
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
