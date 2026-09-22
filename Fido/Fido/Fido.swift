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
/// `ASAuthorization` delegate callback or timeout fires. Starting a new ceremony
/// (`register`/`authenticate`/`authenticateWithAutoFill`) or calling `cancel()` while one is
/// already in flight supersedes it: the superseded ceremony's completion is invoked
/// synchronously with `.failure(FidoError.canceled)` before the new ceremony's state is set, and
/// an identity check in the `ASAuthorizationControllerDelegate` methods discards any late
/// callback from the superseded `ASAuthorizationController`. This is what lets a long-lived
/// `authenticateWithAutoFill` listener coexist with a button-triggered `authenticate` ceremony
/// on the same `Fido.shared` singleton.
public class Fido: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    /// The shared singleton FIDO instance.
    @MainActor
    public static let shared = Fido()

    var window: ASPresentationAnchor?
    var completion: ((Result<[String: Any], Error>) -> Void)?
    var timeoutTask: Task<Void, Never>?
    var authorizationController: ASAuthorizationController?

    /// Monotonically increasing identity for the current ceremony, bumped by
    /// `supersedeInFlightCeremony()`. Lets a scheduled timeout (`startTimeout`/`fireTimeout`)
    /// detect that it has been superseded even after it has already passed its
    /// `Task.isCancelled` check, closing a race the delegate methods' `===` identity guard alone
    /// doesn't cover.
    var ceremonyGeneration = 0

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
        supersedeInFlightCeremony()
        let generation = ceremonyGeneration
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
                    startTimeout(milliseconds: timeout, generation: generation)
                }

                // 5. Perform requests
                logger?.d("Fido: Performing registration requests (\(requests.count) request(s))")
                let authorizationController = makeAuthorizationController(requests: requests)
                authorizationController.performRequests()
            }
        } catch {
            logger?.e("Fido: Registration failed", error: error)
            completion(.failure(error))
            cleanup()
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
        supersedeInFlightCeremony()
        let generation = ceremonyGeneration
        self.logger = logger
        logger?.d("Fido: Starting authentication")
        self.window = window
        self.completion = completion

        do {
            let (authenticationOptions, challengeData) = try decodeAuthenticationOptions(options)
            let assertionRequest = makePlatformAssertionRequest(from: authenticationOptions, challenge: challengeData)

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
                startTimeout(milliseconds: timeout, generation: generation)
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
            cleanup()
        }
    }

    /// Starts a WebAuthn Conditional UI (autofill-assisted) authentication ceremony.
    ///
    /// Unlike `authenticate`, this builds only a single platform (passkey) assertion request —
    /// `ASAuthorizationController.performAutoFillAssistedRequests()` requires exactly one platform
    /// public-key credential assertion request, so no cross-platform security-key request is ever
    /// built, regardless of `allowCredentials`. No timeout is scheduled: the ceremony is meant to
    /// stay active for the lifetime of the autofillable text field, not a fixed duration — callers
    /// are responsible for calling `cancel()` when the field is torn down (or superseding it by
    /// starting another ceremony, e.g. a button-triggered `authenticate()`).
    ///
    /// - Parameters:
    ///   - options: A dictionary containing the authentication options.
    ///   - window: The window to present the autofill-assisted UI in.
    ///   - logger: Optional logger for ceremony state transitions and errors. Scoped to this call
    ///     only — overwritten by subsequent ceremonies and cleared in `cleanup()`.
    ///   - completion: A closure to be called with the authentication result.
    public func authenticateWithAutoFill(options: [String: Any], window: ASPresentationAnchor, logger: Logger? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        supersedeInFlightCeremony()
        self.logger = logger
        logger?.d("Fido: Starting autofill-assisted authentication")
        self.window = window
        self.completion = completion

        do {
            let (authenticationOptions, challengeData) = try decodeAuthenticationOptions(options)
            let assertionRequest = makePlatformAssertionRequest(from: authenticationOptions, challenge: challengeData)

            let authorizationController = makeAuthorizationController(requests: [assertionRequest])
            logger?.d("Fido: Performing autofill-assisted authentication request")
            // `performAutoFillAssistedRequests()` is iOS-only — the SDK header marks it
            // API_UNAVAILABLE(macos, macCatalyst) (verified in Xcode 27.0's ASAuthorizationController.h,
            // both the macOS SDK and its iOSSupport/Catalyst copy), even though Apple's docs page lists
            // Mac Catalyst 16.0+. The compiler follows the header, so Catalyst falls back to the same
            // modal flow as native macOS: Conditional UI has no Catalyst surface at all.
            #if os(iOS) && !targetEnvironment(macCatalyst)
            authorizationController.performAutoFillAssistedRequests()
            #else
            authorizationController.performRequests()
            #endif
        } catch {
            logger?.e("Fido: Autofill-assisted authentication failed", error: error)
            completion(.failure(error))
            cleanup()
        }
    }

    /// Cancels the in-flight ceremony (registration, authentication, or autofill-assisted
    /// authentication), if any.
    ///
    /// The captured completion is invoked synchronously with `.failure(FidoError.canceled)` —
    /// deterministic, not dependent on the underlying `ASAuthorizationController`'s asynchronous
    /// delegate callback — before the controller itself is told to cancel. Safe to call when
    /// nothing is in flight (no-op).
    public func cancel() {
        supersedeInFlightCeremony()
    }

    /// Cancels the in-flight ceremony only if it is still the one identified by `generation`.
    ///
    /// Teardown paths that race with ceremony starts — e.g. `withTaskCancellationHandler`'s
    /// `onCancel`, which may run *after* the cancelled operation has already returned — must not
    /// unconditionally kill whatever ceremony is current by then: that could be an unrelated
    /// newer ceremony on the same singleton (the next journey node's own FIDO call, say). This
    /// variant, unlike `cancel()`, supersedes nothing unless `generation` still identifies the
    /// current ceremony. Intentionally internal: external callers always want the unconditional
    /// `cancel()`.
    ///
    /// - Parameter generation: The `ceremonyGeneration` value captured by the caller's ceremony.
    public func cancel(generation: Int) {
        guard generation == ceremonyGeneration else {
            logger?.d("Fido: Skipping cancel — the ceremony has already been superseded")
            return
        }
        supersedeInFlightCeremony()
    }

    /// Decodes and validates the authentication options shared by `authenticate` and
    /// `authenticateWithAutoFill`.
    private func decodeAuthenticationOptions(_ options: [String: Any]) throws -> (PublicKeyCredentialRequestOptions, Data) {
        let jsonData = try JSONSerialization.data(withJSONObject: options, options: [])
        let authenticationOptions = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: jsonData)
        guard let challengeData = Data(base64Encoded: authenticationOptions.challenge, options: .ignoreUnknownCharacters) else {
            throw FidoError.invalidChallenge
        }
        return (authenticationOptions, challengeData)
    }

    /// Builds the platform (passkey) assertion request shared by `authenticate` and
    /// `authenticateWithAutoFill`.
    private func makePlatformAssertionRequest(from authenticationOptions: PublicKeyCredentialRequestOptions, challenge: Data) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: authenticationOptions.rpId ?? "")
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: authenticationOptions.userVerification?.rawValue ?? "preferred")
        return assertionRequest
    }

    /// Supersedes any in-flight ceremony: synchronously completes it with
    /// `.failure(FidoError.canceled)`, tells the underlying `ASAuthorizationController` to cancel
    /// (fire-and-forget — becomes a no-op once state below is cleared), and clears instance state.
    /// No-op if nothing is in flight. Shared by `cancel()` and the start of `register`,
    /// `authenticate`, and `authenticateWithAutoFill`.
    private func supersedeInFlightCeremony() {
        // Bumped unconditionally, even when nothing is in flight, so every ceremony this
        // instance ever starts (or explicit `cancel()`) gets a fresh identity to compare against.
        ceremonyGeneration += 1
        guard let controller = authorizationController else { return }
        logger?.d("Fido: Superseding in-flight ceremony")
        let pendingCompletion = completion
        cleanup()
        controller.cancel()
        pendingCompletion?(.failure(FidoError.canceled))
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
        // `cancel()`/a new ceremony can supersede this controller before its delegate callback
        // arrives — `ASAuthorizationController.cancel()` re-invokes the delegate asynchronously,
        // so a stale callback from an already-superseded controller must not touch the new
        // ceremony's state.
        guard controller === self.authorizationController else {
            logger?.d("Fido: Ignoring stale authorization completion from a superseded ceremony")
            return
        }
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
        guard controller === self.authorizationController else {
            logger?.d("Fido: Ignoring stale authorization error from a superseded ceremony")
            return
        }
        logger?.e("Fido: Authorization failed", error: error)
        cancelTimeout()
        completion?(.failure(error))
        cleanup()
    }
    
    // MARK: - Timeout Management

    /// Starts a timeout task that will cancel the authorization after the specified duration.
    ///
    /// - Parameters:
    ///   - milliseconds: The timeout duration in milliseconds.
    ///   - generation: The `ceremonyGeneration` captured by the ceremony that scheduled this
    ///     timeout. The `Task.isCancelled` check below only catches cancellation that lands
    ///     *before* the check runs; a supersede that lands after the check passes but before the
    ///     `MainActor.run` body executes would otherwise still fire against whatever ceremony is
    ///     current by then. `fireTimeout(generation:)` re-checks this generation once actually
    ///     isolated on the actor, closing that window.
    private func startTimeout(milliseconds: Int, generation: Int) {
        // Cancel any existing timeout
        cancelTimeout()

        let timeoutSeconds = Double(milliseconds) / 1000.0

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.fireTimeout(generation: generation, timeoutSeconds: timeoutSeconds)
            }
        }
    }

    /// Fires the timeout for a specific ceremony generation: cancels the authorization
    /// controller and completes with `FidoError.timeout`. No-op if a newer ceremony has since
    /// superseded this one (`generation` no longer matches `ceremonyGeneration`) — see
    /// `startTimeout`'s doc comment for why this guard is necessary. Exposed (not `private`) so
    /// tests can simulate the stale-timeout race deterministically.
    func fireTimeout(generation: Int, timeoutSeconds: Double = 0) {
        guard generation == ceremonyGeneration else {
            logger?.d("Fido: Ignoring stale timeout from a superseded ceremony")
            return
        }
        logger?.d("Fido: Operation timed out after \(Int(timeoutSeconds))s")
        authorizationController?.cancel()
        completion?(.failure(FidoError.timeout))
        cleanup()
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
    /// The ceremony was superseded by a new one, or explicitly cancelled via `Fido.cancel()`.
    /// Distinct from the native `ASAuthorizationError.canceled`, which means the user dismissed
    /// a modal system sheet.
    case canceled

    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "FIDO ceremony was superseded by a new request or cancelled"
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
