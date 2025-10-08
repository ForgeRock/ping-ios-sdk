//
//  Fido.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices

/// Fido2 is a class that provides FIDO2 registration and authentication functionalities.
public class Fido2: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    /// The shared singleton Fido2 instance.
    public static let shared = Fido2()
    
    private var window: ASPresentationAnchor?
    private var completion: ((Result<[String: Any], Error>) -> Void)?
    
    /// Registers a new FIDO2 credential.
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the registration options.
    ///   - window: The window to present the registration UI in.
    ///   - completion: A closure to be called with the registration result.
    public func register(options: [String: Any], window: ASPresentationAnchor, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.window = window
        self.completion = completion
        
        do {
            // Use the Codable struct for safe decoding
            let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
            let registrationOptions = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: jsonData)
            
            let relyingParty = registrationOptions.rp.id ?? ""
            
            // Prepare common parameters for the requests
            guard let challengeData = Data(base64Encoded: registrationOptions.challenge, options: .ignoreUnknownCharacters) else {
                completion(.failure(FidoError.invalidChallenge))
                return
            }
            let userID = Data(registrationOptions.user.id.utf8)
            
            var requests: [ASAuthorizationRequest] = []
            
            if registrationOptions.authenticatorSelection?.authenticatorAttachment != .crossPlatform {
                let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
                let platformRequest = platformProvider.createCredentialRegistrationRequest(challenge: challengeData, name: registrationOptions.user.name, userID: userID)
                platformRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: registrationOptions.authenticatorSelection?.userVerification?.rawValue ?? "preferred")
                platformRequest.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(rawValue: registrationOptions.attestation?.rawValue ?? "none")
                requests.append(platformRequest)
            }
            
            if registrationOptions.authenticatorSelection?.authenticatorAttachment != .platform {
                let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: registrationOptions.rp.id ?? "")
                let securityKeyRequest = securityKeyProvider.createCredentialRegistrationRequest(
                    challenge: challengeData,
                    displayName: registrationOptions.user.displayName,
                    name: registrationOptions.user.name,
                    userID: userID
                )
                securityKeyRequest.residentKeyPreference = (registrationOptions.authenticatorSelection?.requireResidentKey == true) ? .required : .discouraged
                securityKeyRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: registrationOptions.authenticatorSelection?.userVerification?.rawValue ?? "preferred")
                securityKeyRequest.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(rawValue: registrationOptions.attestation?.rawValue ?? "none")
                
                // Configure credential parameters (algorithms)
                securityKeyRequest.credentialParameters = registrationOptions.pubKeyCredParams.compactMap { param -> ASAuthorizationPublicKeyCredentialParameters? in
                    switch param.alg {
                    case .es256:
                        return ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)
                    default:
                        return nil
                    }
                }
                // If resident key is not required, only use the securityKeyRequest
                if registrationOptions.authenticatorSelection?.requireResidentKey == false {
                    requests = [securityKeyRequest]
                } else {
                    requests.append(securityKeyRequest)
                }
                
            }
            
            // 3. Perform the requests. The system will merge the UI prompts automatically.
            let authorizationController = ASAuthorizationController(authorizationRequests: requests)
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Authenticates with an existing FIDO2 credential.
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the authentication options.
    ///   - window: The window to present the authentication UI in.
    ///   - completion: A closure to be called with the authentication result.
    public func authenticate(options: [String: Any], window: ASPresentationAnchor, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.window = window
        self.completion = completion
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
            let authenticationOptions = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: jsonData)
            
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: authenticationOptions.rpId ?? "")
            
            guard let challengeData = Data(base64Encoded: authenticationOptions.challenge, options: .ignoreUnknownCharacters) else {
                completion(.failure(FidoError.invalidChallenge))
                return
            }
            let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
            assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: authenticationOptions.userVerification?.rawValue ?? "preferred")
            
            var requests: [ASAuthorizationRequest] = [assertionRequest]
            
            if let allowCredentials = authenticationOptions.allowCredentials, !allowCredentials.isEmpty {
                let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: authenticationOptions.rpId ?? "")
                let securityKeyRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challengeData)
                securityKeyRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: authenticationOptions.userVerification?.rawValue ?? "preferred")
                securityKeyRequest.allowedCredentials = allowCredentials.compactMap { cred -> ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor? in
                    guard let idData = Data(base64Encoded: cred.id) else {
                        return nil
                    }
                    
                    return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: idData, transports: [])
                }
                requests.append(securityKeyRequest)
            }
            
            let authorizationController = ASAuthorizationController(authorizationRequests: requests)
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        } catch {
            completion(.failure(error))
        }
    }
    
    /// ASAuthorizationControllerDelegate method that returns the presentation anchor for the authorization controller.
    ///
    /// - Parameter controller: The authorization controller.
    /// - Returns: The presentation anchor.
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = window else {
            fatalError("Window not set")
        }
        return window
    }
    
    /// ASAuthorizationControllerDelegate method that handles the authorization controller completion with authorization.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - authorization: The authorization.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let credential as ASAuthorizationPublicKeyCredentialRegistration:
            let int8Arr = credential.rawAttestationObject?.bytesArray.map { Int8(bitPattern: $0) }
            let attestationObject = convertInt8ArrToStr(int8Arr ?? [])
            
            let clientDataJSON = String(decoding: credential.rawClientDataJSON, as: UTF8.self)
            
            let credID = base64ToBase64url(base64: credential.credentialID.base64EncodedString())
            
            let result: [String: Any] = [
                FidoConstants.FIELD_CLIENT_DATA_JSON: clientDataJSON,
                FidoConstants.FIELD_ATTESTATION_OBJECT: attestationObject,
                FidoConstants.FIELD_RAW_ID: credID
            ]
            completion?(.success(result))
            
        case let credential as ASAuthorizationPublicKeyCredentialAssertion:
            // Verify the below signature and clientDataJSON with your service for the given userID.
            
            let signatureInt8 = credential.signature.bytesArray.map { Int8(bitPattern: $0) }
            let signature = convertInt8ArrToStr(signatureInt8)
            let clientDataJSON = String(decoding: credential.rawClientDataJSON, as: UTF8.self)
            let authenticatorDataInt8 = credential.rawAuthenticatorData.bytesArray.map { Int8(bitPattern: $0) }
            let authenticatorData = convertInt8ArrToStr(authenticatorDataInt8)
            let credID = base64ToBase64url(base64: credential.credentialID.base64EncodedString())
            let userIDString = String(decoding: credential.userID, as: UTF8.self)
            //  Expected AM result for successful assertion
            
            //  {clientDataJSON as String}::{Int8 array of authenticatorData}::{Int8 array of signature}::{assertion identifier}::{user handle}
            let result: [String: Any] = [
                FidoConstants.FIELD_CLIENT_DATA_JSON: clientDataJSON,
                FidoConstants.FIELD_AUTHENTICATOR_DATA: authenticatorData,
                FidoConstants.FIELD_SIGNATURE: signature,
                FidoConstants.FIELD_RAW_ID: credID,
                FidoConstants.FIELD_USER_HANDLE: userIDString
            ]
            completion?(.success(result))
            
        default:
            break
        }
    }
    
    /// ASAuthorizationControllerDelegate method that handles the authorization controller completion with an error.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - error: The error.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
    }
}

/// Represents an error that can occur during FIDO2 operations.
public enum FidoError: Error {
    case invalidChallenge
    case invalidWindow
}
