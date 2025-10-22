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

/// Fido is a class that provides FIDO registration and authentication functionalities.
public class Fido: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    /// The shared singleton FIDO instance.
    public static let shared = Fido()
    
    var window: ASPresentationAnchor?
    var completion: ((Result<[String: Any], Error>) -> Void)?
    
    func makeAuthorizationController(requests: [ASAuthorizationRequest]) -> ASAuthorizationController {
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        return authorizationController
    }
    
    /// Registers a new FIDO credential.
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the registration options.
    ///   - window: The window to present the registration UI in.
    ///   - completion: A closure to be called with the registration result.
    public func register(options: [String: Any], window: ASPresentationAnchor, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.window = window
        self.completion = completion
        
        do {
            // 1. Decode options
            let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
            let registrationOptions = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: jsonData)
            
            // 2. Prepare common parameters
            guard let challengeData = Data(base64Encoded: registrationOptions.challenge, options: .ignoreUnknownCharacters) else {
                completion(.failure(FidoError.invalidChallenge))
                return
            }
            let userID = Data(registrationOptions.user.id.utf8)
            
            // 3. Determine which requests to create based on selection criteria
            var requests: [ASAuthorizationRequest] = []
            let attachment = registrationOptions.authenticatorSelection?.authenticatorAttachment
            let requireResidentKey = registrationOptions.authenticatorSelection?.requireResidentKey

            // Add platform request (Passkey) if:
            // - Attachment is .platform OR nil (no preference)
            // - AND requireResidentKey is NOT explicitly false (since Passkeys are always resident)
            if attachment != .crossPlatform && requireResidentKey != false {
                let platformRequest = self.createPlatformRequest(
                    from: registrationOptions,
                    challenge: challengeData,
                    userID: userID
                )
                requests.append(platformRequest)
            }
            
            // Add security key request if:
            // - Attachment is .crossPlatform OR nil (no preference)
            if attachment != .platform {
                let securityKeyRequest = self.createSecurityKeyRequest(
                    from: registrationOptions,
                    challenge: challengeData,
                    userID: userID
                )
                requests.append(securityKeyRequest)
            }
            
            // 4. Perform requests
            let authorizationController = makeAuthorizationController(requests: requests)
            authorizationController.performRequests()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Authenticates with an existing FIDO credential.
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
    
    /// Handles the completion of an authorization request with an error.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - error: The error that occurred.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
    }
    
    // MARK: - Private Request Builders
    
    /// Creates a platform request based on the provided options.
    /// - Parameters:
    /// - options: The public key credential creation options.
    /// - challenge: The challenge data.
    /// - userID: The user ID data.
    /// - Returns: An `ASAuthorizationRequest` configured for platform registration.
    private func createPlatformRequest(from options: PublicKeyCredentialCreationOptions, challenge: Data, userID: Data) -> ASAuthorizationRequest {
        let relyingParty = options.rp.id ?? ""
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
        let request = provider.createCredentialRegistrationRequest(challenge: challenge, name: options.user.name, userID: userID)
        
        let authSelection = options.authenticatorSelection
        request.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(
            rawValue: authSelection?.userVerification?.rawValue ?? "preferred"
        )
        request.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(
            rawValue: options.attestation?.rawValue ?? "none"
        )
        
        return request
    }

    /// Creates a security key request based on the provided options.
    /// - Parameters:
    ///  - options: The public key credential creation options.
    ///  - challenge: The challenge data.
    ///  - userID: The user ID data.
    ///  - Returns: An `ASAuthorizationRequest` configured for security key registration.
    private func createSecurityKeyRequest(from options: PublicKeyCredentialCreationOptions, challenge: Data, userID: Data) -> ASAuthorizationRequest {
        let relyingParty = options.rp.id ?? ""
        let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            displayName: options.user.displayName,
            name: options.user.name,
            userID: userID
        )
        
        let authSelection = options.authenticatorSelection
        request.residentKeyPreference = (authSelection?.requireResidentKey == true) ? .required : .discouraged
        request.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(
            rawValue: authSelection?.userVerification?.rawValue ?? "preferred"
        )
        request.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(
            rawValue: options.attestation?.rawValue ?? "none"
        )
        
        // Configure credential parameters (algorithms)
        request.credentialParameters = options.pubKeyCredParams.compactMap { param in
            guard let alg = COSEAlgorithmIdentifier(rawValue: param.alg.rawValue) else { return nil }
            
            switch alg {
            case .es256:
                return ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)
            default:
                // Add other supported algorithms here if needed
                return nil
            }
        }
        
        return request
    }
    
    /// Processes the provided authorization credential and calls the completion handler.
    /// - Parameter credential: The authorization credential to process.
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
}

/// Represents an error that can occur during FIDO operations.
public enum FidoError: Error, Equatable {
    case invalidChallenge
    case invalidWindow
    case invalidResponse
    case invalidAction
    case unsupportedAction(String)
    case missingParameters(String)
}
