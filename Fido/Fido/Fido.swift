//
//  Fido.swift
//  Fido
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
import PingLogger

/// Fido is a class that provides FIDO registration and authentication functionalities.
///
/// `Fido` is single-flight: a registration or authentication ceremony retains state on the
/// instance (window, completion handler, logger, timeout task) until the underlying
/// `ASAuthorization` delegate callback or timeout fires. Concurrent ceremonies on the same
/// instance will overwrite each other, which is why callers consume it through the
/// `Fido.shared` singleton serialized by the surrounding workflow.
public class Fido: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    /// The shared singleton FIDO instance.
    @MainActor
    public static let shared = Fido()

    var window: ASPresentationAnchor?
    var completion: ((Result<[String: Any], Error>) -> Void)?
    var timeoutTask: Task<Void, Never>?
    var authorizationController: ASAuthorizationController?

    /// Logger for the in-flight ceremony. Set by `register`/`authenticate` and cleared in
    /// `cleanup()`, so each ceremony uses its caller's workflow logger and nothing else.
    private var logger: Logger?
    
    func makeAuthorizationController(requests: [ASAuthorizationRequest]) -> ASAuthorizationController {
        requests.forEach { testRequestCapture?($0) }
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        self.authorizationController = authorizationController
        return authorizationController
    }

    /// Test-only hook. Receives each request before it is handed to `ASAuthorizationController`.
    /// Set this in tests to inspect request properties without triggering the system UI.
    var testRequestCapture: ((ASAuthorizationRequest) -> Void)?
    
    /// Registers a new FIDO credential.
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the registration options.
    ///   - window: The window to present the registration UI in.
    ///   - logger: Optional logger for ceremony state transitions and errors. Pass the
    ///     workflow logger (e.g. `davinci?.config.logger`); when `nil` no log output is
    ///     produced. Scoped to this call only — overwritten by subsequent ceremonies and
    ///     cleared in `cleanup()`.
    ///   - completion: A closure to be called with the registration result.
    public func register(options: [String: Any], window: ASPresentationAnchor, logger: Logger? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.logger = logger
        logger?.d("Fido: Starting registration")
        self.window = window
        self.completion = completion

        do {
            // 1. Decode options
            let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
            let registrationOptions = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: jsonData)

            // 2. Prepare common parameters
            guard let challengeData = Data(base64Encoded: registrationOptions.challenge, options: .ignoreUnknownCharacters) else {
                logger?.e("Fido: Registration failed - invalid challenge", error: nil)
                completion(.failure(FidoError.invalidChallenge))
                cleanup()
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

            if requests.isEmpty {
                logger?.e("Fido: Registration failed - no suitable authentication methods available", error: nil)
                completion(.failure(FidoError.unsupportedAction("No suitable authentication methods available")))
                cleanup()
            } else {
                // 4. Start timeout if specified
                if let timeout = registrationOptions.timeout, timeout > 0 {
                    startTimeout(milliseconds: timeout)
                }

                // 5. Perform requests
                logger?.d("Fido: Performing registration requests (\(requests.count) request(s))")
                let authorizationController = makeAuthorizationController(requests: requests)
                authorizationController.performRequests()
            }
        } catch {
            logger?.e("Fido: Registration failed", error: error)
            completion(.failure(error))
        }
    }
    
    /// Authenticates with an existing FIDO credential.
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the authentication options.
    ///   - window: The window to present the authentication UI in.
    ///   - preferImmediatelyAvailableCredentials: When `true`, the ceremony is restricted to
    ///     platform credentials (passkeys) already present on this device: if a matching passkey
    ///     exists the system presents the modal sign-in sheet, but if none is available no UI
    ///     appears and the delegate receives `ASAuthorizationError.canceled` instead of the QR /
    ///     nearby-device fallback. In this mode the ceremony is platform-only — no cross-platform
    ///     security-key request is issued even when `allowCredentials` is present, since a hardware
    ///     security key is never immediately available on the local device. When `false` (the
    ///     default) the full `performRequests()` flow is used, including cross-device sign-in and
    ///     security keys — preserving the pre-existing behavior. Mirrors the legacy
    ///     `FRWebAuthnManager.signInWith(preferImmediatelyAvailableCredentials:)` option.
    ///   - logger: Optional logger for ceremony state transitions and errors. Pass the
    ///     workflow logger (e.g. `journey?.config.logger`); when `nil` no log output is
    ///     produced. Scoped to this call only — overwritten by subsequent ceremonies and
    ///     cleared in `cleanup()`.
    ///   - completion: A closure to be called with the authentication result.
    public func authenticate(options: [String: Any], window: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool = false, logger: Logger? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.logger = logger
        logger?.d("Fido: Starting authentication")
        self.window = window
        self.completion = completion

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
            let authenticationOptions = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: jsonData)

            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: authenticationOptions.rpId ?? "")

            guard let challengeData = Data(base64Encoded: authenticationOptions.challenge, options: .ignoreUnknownCharacters) else {
                logger?.e("Fido: Authentication failed - invalid challenge", error: nil)
                completion(.failure(FidoError.invalidChallenge))
                cleanup()
                return
            }
            let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
            assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: authenticationOptions.userVerification?.rawValue ?? "preferred")

            var requests: [ASAuthorizationRequest] = [assertionRequest]

            // A hardware security key is never "immediately available on the local device", so a
            // security-key assertion request is incompatible with .preferImmediatelyAvailableCredentials:
            // including it would only be suppressed by the system. When the caller opts into local-only
            // credentials we therefore run a platform-only ceremony, matching the legacy
            // `FRWebAuthnManager.signInWith` behavior which never built a security-key request.
            if !preferImmediatelyAvailableCredentials,
               let allowCredentials = authenticationOptions.allowCredentials, !allowCredentials.isEmpty {
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

            // Start timeout if specified
            if let timeout = authenticationOptions.timeout, timeout > 0 {
                startTimeout(milliseconds: timeout)
            }

            let authorizationController = makeAuthorizationController(requests: requests)
            if preferImmediatelyAvailableCredentials {
                // Restrict to locally-available credentials: presents the sign-in sheet only
                // when a matching passkey exists, otherwise the delegate receives
                // ASAuthorizationError.canceled with no UI (no QR / nearby-device fallback).
                logger?.d("Fido: Performing authentication requests (\(requests.count) request(s)), preferring immediately available credentials")
                authorizationController.performRequests(options: .preferImmediatelyAvailableCredentials)
            } else {
                logger?.d("Fido: Performing authentication requests (\(requests.count) request(s))")
                authorizationController.performRequests()
            }
        } catch {
            logger?.e("Fido: Authentication failed", error: error)
            completion(.failure(error))
        }
    }
    
    ///- Returns: The presentation anchor.
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = window else {
            #if canImport(UIKit)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                return window
            }
            #endif
            // macOS: build target only — this path is unreachable in practice
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
        logger?.d("Fido: Authorization completed successfully")
        cancelTimeout()
        didComplete(with: authorization.credential)
    }

    /// Handles the completion of an authorization request with an error.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller.
    ///   - error: The error that occurred.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger?.e("Fido: Authorization failed", error: error)
        cancelTimeout()
        completion?(.failure(error))
        cleanup()
    }
    
    // MARK: - Timeout Management
    
    /// Starts a timeout task that will cancel the authorization after the specified duration
    ///
    /// - Parameter milliseconds: The timeout duration in milliseconds
    private func startTimeout(milliseconds: Int) {
        // Cancel any existing timeout
        cancelTimeout()

        let timeoutSeconds = Double(milliseconds) / 1000.0
        let capturedLogger = logger

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self = self else { return }

                capturedLogger?.d("Fido: Operation timed out after \(Int(timeoutSeconds))s")

                // Cancel the authorization controller if still active
                self.authorizationController?.cancel()

                // Call completion with timeout error
                let timeoutError = FidoError.timeout
                self.completion?(.failure(timeoutError))

                // Clean up
                self.cleanup()
            }
        }
    }
    
    /// Cancels the timeout task if one is active
    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }
    
    /// Cleans up the state after completion
    private func cleanup() {
        authorizationController = nil
        window = nil
        completion = nil
        logger = nil
        cancelTimeout()
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
        let name: String
        if options.user.displayName.isEmpty {
            name = options.user.name
        } else {
            name = options.user.displayName
        }
        let request: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest = provider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
        request.displayName = options.user.displayName

        // Map excludeCredentials to ASAuthorizationPlatformPublicKeyCredentialDescriptor
        if let excludeCredentials = options.excludeCredentials {
            if #available(iOS 17.4, macOS 13.5, *) {
                request.excludedCredentials = excludeCredentials.compactMap { descriptor -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? in
                    guard let credentialIDData = Data(base64Encoded: descriptor.id, options: .ignoreUnknownCharacters) else {
                        return nil
                    }
                    return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialIDData)
                }
            }
        }
        
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
        
        // Map excludeCredentials to ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor
        if let excludeCredentials = options.excludeCredentials {
            request.excludedCredentials = excludeCredentials.compactMap { descriptor -> ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor? in
                guard let credentialIDData = Data(base64Encoded: descriptor.id, options: .ignoreUnknownCharacters) else {
                    return nil
                }
                return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: credentialIDData, transports: [])
            }
        }
        
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
            logger?.d("Fido: Processing registration credential")
            // Determine authenticator attachment type
            var attachmentValue: String = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM
            if let registrationCredential = credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                if #available(iOS 16.6, macOS 13.5, *) {
                    attachmentValue = registrationCredential.attachment == .platform ? FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM : FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_CROSS_PLATFORM
                } else {
                    // Fallback for iOS 15 - default to platform since that's the only option on iOS 15
                    attachmentValue = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM
                }
            }
            if credential is ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
                attachmentValue = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_CROSS_PLATFORM
            }
            
            let result: [String: Any] = [
                FidoConstants.FIELD_RAW_ID: credential.credentialID,
                FidoConstants.FIELD_CLIENT_DATA_JSON: credential.rawClientDataJSON,
                FidoConstants.FIELD_ATTESTATION_OBJECT: credential.rawAttestationObject as Any,
                FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: attachmentValue,
            ]
            completion?(.success(result))
            cleanup()
        case let credential as ASAuthorizationPublicKeyCredentialAssertion:
            logger?.d("Fido: Processing authentication credential")
            // Determine authenticator attachment type for assertion
            var attachmentValue: String = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM
            if let assertionCredential = credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                if #available(iOS 16.6, macOS 13.5, *) {
                    attachmentValue = assertionCredential.attachment == .platform ? FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM : FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_CROSS_PLATFORM
                } else {
                    // Fallback for iOS 15 - default to platform since that's the only option on iOS 15
                    attachmentValue = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM
                }
            }
            if credential is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
                attachmentValue = FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_CROSS_PLATFORM
            }
            
            let result: [String: Any] = [
                FidoConstants.FIELD_CLIENT_DATA_JSON: credential.rawClientDataJSON,
                FidoConstants.FIELD_AUTHENTICATOR_DATA: credential.rawAuthenticatorData ?? Data(),
                FidoConstants.FIELD_SIGNATURE: credential.signature ?? Data(),
                FidoConstants.FIELD_RAW_ID: credential.credentialID,
                FidoConstants.FIELD_USER_HANDLE: credential.userID ?? Data(),
                FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: attachmentValue
            ]
            completion?(.success(result))
            cleanup()
            
        default:
            break
        }
    }
}

/// Represents an error that can occur during FIDO operations.
public enum FidoError: Error, LocalizedError, Equatable, Sendable {
    case invalidChallenge
    case invalidWindow
    case invalidResponse
    case invalidAction
    case unsupportedAction(String)
    case missingParameters(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "ERROR::TimeoutError:Operation timedout"
        case .invalidChallenge:
            return "Invalid challenge"
        case .invalidWindow:
            return "Invalid window"
        case .invalidResponse:
            return "Invalid response"
        case .invalidAction:
            return "Invalid action"
        case .unsupportedAction(let message):
            return "Unsupported action: \(message)"
        case .missingParameters(let message):
            return "Missing parameters: \(message)"
        }
    }
}
