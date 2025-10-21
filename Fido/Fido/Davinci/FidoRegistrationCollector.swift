//
//  FidoRegistrationCollector.swift
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

/// A collector for FIDO registration within a DaVinci flow.
public class FidoRegistrationCollector: AbstractFidoCollector, @unchecked Sendable {
    
    /// The public key credential creation options provided by the server.
    public var publicKeyCredentialCreationOptions: [String: Any] = [:]
    /// The attestation value constructed after a successful registration. This value is sent to the server.
    public var attestationValue: [String: Any]?
    
    /// Initializes a new FIDO registration collector.
    ///
    /// - Parameter json: The JSON payload from the server that includes the FIDO registration options.
    /// - Throws: An error if the required `publicKeyCredentialCreationOptions` parameter is missing from the JSON.
    required public init(with json: [String : Any]) {
        super.init(with: json)
        logger?.d("Initializing FIDO registration collector")
        guard let options = json[FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS] as? [String: Any] else {
            logger?.e("Missing \(FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS)", error: nil)
            return
        }
        self.publicKeyCredentialCreationOptions = self.transform(options)
        logger?.d("FIDO registration collector initialized with creation options")
    }
    
    /// The payload to be sent to the DaVinci server.
    ///
    /// - Returns: A dictionary containing the attestation value, or `nil` if registration has not been completed.
    override public func payload() -> [String: Any]? {
        guard let attestationValue = attestationValue else {
            logger?.d("No attestation value available, returning null payload")
            return nil
        }
        logger?.d("Returning attestation payload for FIDO registration")
        return [FidoConstants.FIELD_ATTESTATION_VALUE: attestationValue]
    }
    
    
    /// Initiates the FIDO registration process using async/await.
    ///
    /// This method uses the `fido.register` method to perform the registration ceremony.
    /// On success, it constructs and stores the `attestationValue`, then returns it.
    /// - Parameter window: The `ASPresentationAnchor` to present the FIDO UI.
    /// - Returns: A dictionary representing the `attestationValue`.
    /// - Throws: An error if the registration process fails or the response is invalid.
    @MainActor
    public func register(window: ASPresentationAnchor) async throws -> [String: Any] {
        logger?.d("Starting FIDO registration (async)")

        do {
            // 1. Wrap the closure-based fido.register in a continuation
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                 // Assuming 'fido' is accessible
                fido.register(options: publicKeyCredentialCreationOptions, window: window) { result in
                    continuation.resume(with: result)
                }
            }

            // 2. Process the successful response
            logger?.d("FIDO registration successful, building attestationValue object...")

            guard let rawIdData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                  let clientDataJSONData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                  let attestationObjectData = response[FidoConstants.FIELD_ATTESTATION_OBJECT] as? Data else {
                
                let error = FidoError.invalidResponse
                logger?.e(error.localizedDescription, error: error)
                throw error // Throw directly in async context
            }
            
            let authenticatorAttachment = "platform"

            // Construct the attestationValue payload
            let newAttestationValue: [String: Any] = [
                FidoConstants.FIELD_ID: rawIdData.base64urlEncodedString(),
                FidoConstants.FIELD_TYPE: FidoConstants.FIELD_PUB_KEY,
                FidoConstants.FIELD_RAW_ID: rawIdData.base64EncodedString(),
                FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: authenticatorAttachment,
                FidoConstants.FIELD_RESPONSE: [
                    FidoConstants.FIELD_CLIENT_DATA_JSON: clientDataJSONData.base64urlEncodedString(),
                    FidoConstants.FIELD_ATTESTATION_OBJECT: attestationObjectData.base64urlEncodedString()
                ]
            ]
            
            logger?.d("attestationValue object created successfully")
            self.attestationValue = newAttestationValue // Store the value
            return newAttestationValue // Return the value
            
        } catch {
            // 3. Handle errors from the continuation or guard statement
            logger?.e("FIDO registration failed", error: error)
            throw error // Re-throw the error
        }
    }
    
    // MARK: - Private Transform
    
    /// Transforms the FIDO registration request options from the server to the format expected by the `ASAuthorization` framework.
    ///
    /// This involves converting byte arrays for `user.id`, `challenge`, and `excludeCredentials` IDs to Base64 encoded strings.
    /// - Parameter input: The dictionary of options received from the server.
    /// - Returns: A transformed dictionary of options.
    private func transform(_ input: [String: Any]) -> [String: Any] {
        logger?.d("Transforming FIDO registration creation options")
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
        
        logger?.d("FIDO registration creation options transformed successfully")
        return output
    }
}
