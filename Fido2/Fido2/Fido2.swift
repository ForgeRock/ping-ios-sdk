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
    
    var window: ASPresentationAnchor?
    var completion: ((Result<[String: Any], Error>) -> Void)?
    
    func makeAuthorizationController(requests: [ASAuthorizationRequest]) -> ASAuthorizationController {
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        return authorizationController
    }
    
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
                    guard let alg = COSEAlgorithmIdentifier(rawValue: param.alg.rawValue) else {
                        return nil
                    }
                    switch alg {
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
            
            let authorizationController = makeAuthorizationController(requests: requests)
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
            
            let authorizationController = makeAuthorizationController(requests: requests)
            authorizationController.performRequests()
        } catch {
            completion(.failure(error))
        }
    }
    
    ///- Returns: The presentation anchor.
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = window else {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                return window
            }
            fatalError("Window not set. This should never occur.")
        }
        return window
    }
    
    /// Handles the successful completion of an authorization request.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - authorization: The authorization object containing the credential.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        didComplete(with: authorization.credential)
    }
    
    func didComplete(with credential: ASAuthorizationCredential) {
        switch credential {
        case let credential as ASAuthorizationPublicKeyCredentialRegistration:
            let result: [String: Any] = [
                FidoConstants.FIELD_RAW_ID: credential.credentialID,
                FidoConstants.FIELD_CLIENT_DATA_JSON: credential.rawClientDataJSON,
                FidoConstants.FIELD_ATTESTATION_OBJECT: credential.rawAttestationObject as Any
            ]
            completion?(.success(result))
        case let credential as ASAuthorizationPublicKeyCredentialAssertion:
            let result: [String: Any] = [
                FidoConstants.FIELD_CLIENT_DATA_JSON: credential.rawClientDataJSON,
                FidoConstants.FIELD_AUTHENTICATOR_DATA: credential.rawAuthenticatorData ?? Data(),
                FidoConstants.FIELD_SIGNATURE: credential.signature ?? Data(),
                FidoConstants.FIELD_RAW_ID: credential.credentialID,
                FidoConstants.FIELD_USER_HANDLE: credential.userID ?? Data()
            ]
            completion?(.success(result))
            
        default:
            break
        }
    }
    
    /// Handles the completion of an authorization request with an error.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - error: The error that occurred.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
    }
}

/// Represents an error that can occur during FIDO2 operations.
public enum FidoError: Error, Equatable {
    case invalidChallenge
    case invalidWindow
    case invalidResponse
    case invalidAction
    case unsupportedAction(String)
    case missingParameters(String)
}
