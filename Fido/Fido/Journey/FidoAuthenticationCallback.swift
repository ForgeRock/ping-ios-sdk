//
//  FidoAuthenticationCallback.swift
//  Fido
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin
import AuthenticationServices
import PingLogger
import PingCommons

/// A callback for handling FIDO authentication in a PingOne Journey.
public class FidoAuthenticationCallback: FidoCallback, @unchecked Sendable {
    
    /// The `PublicKeyCredentialRequestOptions` received from the server for FIDO authentication.
    public var publicKeyCredentialRequestOptions: [String: Any] = [:]

    /// A flag indicating whether the server supports a JSON response format.
    private var supportsJsonResponse: Bool = false

    /// Whether the server requested WebAuthn Conditional UI (autofill-assisted) mediation for
    /// this ceremony. Parsed defensively from the `mediation`/`conditional` fields on the
    /// `MetadataCallback` payload — mirroring the Ping JavaScript SDK's
    /// `meta.mediation === 'conditional' || meta.conditional === true` check, since both fields
    /// are present in the real AM payload. Callers use this to decide whether to invoke
    /// `authenticateWithAutoFill(window:)` instead of `authenticate(window:)`.
    public var isConditionalMediationRequested: Bool = false

    /// Whether the server wants a manual "Sign in with a passkey" button shown alongside
    /// Conditional UI. Defaults to `true` (matching the server's own default) when the field is
    /// absent from the payload.
    public var isManualButtonEnabled: Bool = true

    /// Initializes the callback's properties with values from the JSON payload.
    ///
    /// - Parameters:
    ///   - name: The name of the property to initialize.
    ///   - value: The value of the property.
    public override func initValue(name: String, value: Any) {
        if name == FidoConstants.FIELD_DATA, let data = value as? [String: Any] {
            logger.d("Processing FIDO authentication data")
            supportsJsonResponse = data[FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE] as? Bool ?? false
            let mediation = data[FidoConstants.FIELD_MEDIATION] as? String
            let conditionalFlag = data[FidoConstants.FIELD_CONDITIONAL] as? Bool ?? false
            isConditionalMediationRequested = (mediation == FidoConstants.MEDIATION_CONDITIONAL) || conditionalFlag
            isManualButtonEnabled = data[FidoConstants.FIELD_MANUAL_BUTTON_ENABLED] as? Bool ?? true
            publicKeyCredentialRequestOptions = transform(data)
            logger.d("FIDO authentication callback initialized successfully")
        }
    }
    
    /// Initiates the FIDO authentication process using async/await.
    ///
    /// - Parameters:
    ///   - window: The `ASPresentationAnchor` to present the FIDO UI.
    ///   - preferImmediatelyAvailableCredentials: When `true`, restricts the ceremony to
    ///     credentials already present on this device — no QR / nearby-device fallback is
    ///     shown, and the call fails (cancelled) when no local passkey exists. Defaults to
    ///     `false`, preserving the existing full sign-in behavior.
    /// - Throws: An error if the authentication process fails.
    @MainActor
    public func authenticate(window: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool = false) async -> Result<[String: Any], Error> {
        logger.d("Starting FIDO authentication (async Result)")
        return await performAuthentication(isMediated: false) { completion in
            // Pass the workflow logger so the underlying ASAuthorization ceremony
            // emits log messages through the same logger as the surrounding flow.
            fido.authenticate(options: publicKeyCredentialRequestOptions, window: window, preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials, logger: logger, completion: completion)
        }
    }

    /// Initiates a WebAuthn Conditional UI (autofill-assisted) authentication ceremony.
    ///
    /// Intended for a username field the app has wired to autofill suggestions (via
    /// `UITextContentType.username`) — call this when `isConditionalMediationRequested` is
    /// `true`. Unlike `authenticate`, this ceremony stays active until a credential is selected
    /// or the ceremony is cancelled/superseded (e.g. by a subsequent `authenticate(window:)` call
    /// from a manual "Sign in with a passkey" button). If the underlying `Task` is cancelled
    /// (e.g. the hosting SwiftUI view disappears), the ceremony is cancelled automatically;
    /// callers that don't rely on structured-concurrency cancellation should call
    /// `cancel()` explicitly on teardown.
    ///
    /// - Parameter window: The `ASPresentationAnchor` to present the FIDO UI in.
    @MainActor
    public func authenticateWithAutoFill(window: ASPresentationAnchor) async -> Result<[String: Any], Error> {
        logger.d("Starting FIDO Conditional UI (autofill-assisted) authentication")
        return await withTaskCancellationHandler {
            await performAuthentication(isMediated: true) { completion in
                fido.authenticateWithAutoFill(options: publicKeyCredentialRequestOptions, window: window, logger: logger, completion: completion)
            }
        } onCancel: {
            Task { @MainActor in self.fido.cancel() }
        }
    }

    /// Shared implementation for `authenticate`/`authenticateWithAutoFill`: wraps the
    /// closure-based `fido.xxx(...)` call in a continuation, parses the successful response into
    /// the callback value, and handles errors.
    ///
    /// - Parameters:
    ///   - isMediated: `true` for the Conditional UI (autofill-assisted) path. When `true`, a
    ///     cancellation-shaped error (`FidoError.canceled`, or the native
    ///     `ASAuthorizationError.canceled`) is treated as a silent client-side supersession/
    ///     teardown of a passive listener the user never interacted with — nothing is written to
    ///     the `WEB_AUTHN_OUTCOME` hidden callback. When `false` (the traditional button-triggered
    ///     path), every error — including a native cancellation from the user dismissing the
    ///     modal sheet — is still reported via `handleError`, unchanged from prior behavior.
    ///   - invoke: Invokes the underlying `fido` ceremony with the given completion.
    @MainActor
    private func performAuthentication(
        isMediated: Bool,
        invoke: (@escaping (Result<[String: Any], Error>) -> Void) -> Void
    ) async -> Result<[String: Any], Error> {
        do {
            // 1. Wrap the closure-based fido call in a continuation
            //    This still throws internally within the 'do' block if the continuation resumes with an error.
            let response: [String: Any] = try await withUnsafeThrowingContinuation { continuation in
                invoke { result in
                    Task {
                        await MainActor.run {
                            nonisolated(unsafe) let sendableResult = result
                            continuation.resume(with: sendableResult) // Resume with the Result<[String: Any>, Error>
                        }
                    }
                }
            }

            // 2. Handle the successful response data extraction
            self.logger.d("FIDO authentication successful, processing response...")

            guard let signatureData = response[FidoConstants.FIELD_SIGNATURE] as? Data,
                  let clientData = response[FidoConstants.FIELD_CLIENT_DATA_JSON] as? Data,
                  let authenticatorData = response[FidoConstants.FIELD_AUTHENTICATOR_DATA] as? Data,
                  let credIDData = response[FidoConstants.FIELD_RAW_ID] as? Data,
                  let userHandleData = response[FidoConstants.FIELD_USER_HANDLE] as? Data else {

                let error = FidoError.invalidResponse // Define your error type
                self.logger.e(error.localizedDescription, error: error)
                self.handleError(error: error) // Keep existing error handling side-effect
                return .failure(error) // Return failure
            }

            // 3. Process data and set callback value (side effect)
            let legacyData = [
                String(decoding: clientData, as: UTF8.self),
                Int8.convertInt8ArrToStr(authenticatorData.bytesArray.map { Int8(bitPattern: $0) }, separator: FidoConstants.INT_SEPARATOR),
                Int8.convertInt8ArrToStr(signatureData.bytesArray.map { Int8(bitPattern: $0) }, separator: FidoConstants.INT_SEPARATOR),
                credIDData.base64URLEncodedString(),
                String(decoding: userHandleData, as: UTF8.self)
            ].joined(separator: FidoConstants.DATA_SEPARATOR)

            let callbackValue: String
            let authenticatorAttachment = response[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String ?? FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT_PLATFORM
            if self.supportsJsonResponse {
                let jsonResponse: [String: Any] = [
                    FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: authenticatorAttachment,
                    FidoConstants.FIELD_LEGACY_DATA: legacyData
                ]
                // Safely create JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    callbackValue = jsonString
                } else {
                    // Handle potential JSON serialization error if needed
                    callbackValue = ""
                    logger.w("Failed to serialize FIDO JSON response", error: nil)
                }
            } else {
                callbackValue = legacyData
            }

            self.logger.d("Setting authentication callback value")
            self.valueCallback(value: callbackValue) // Perform side effect

            // 4. Return success with the original response dictionary
            return .success(response)

        } catch {
            // 5. Handle any error caught from the continuation
            self.logger.e("FIDO authentication failed", error: error)
            if isMediated && Self.isCancellation(error) {
                logger.d("FIDO Conditional UI ceremony was superseded or cancelled — not reporting to server")
            } else {
                self.handleError(error: error) // Keep existing error handling side-effect
            }
            return .failure(error) // Return failure
        }
    }

    /// Whether `error` represents a cancellation-shaped signal: either the SDK's own
    /// `FidoError.canceled` (a superseded/explicitly-cancelled ceremony) or the native
    /// `ASAuthorizationError.canceled` (the user dismissed a system sheet, or the controller was
    /// otherwise cancelled).
    private static func isCancellation(_ error: Error) -> Bool {
        if case FidoError.canceled = error {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.canceled.rawValue
    }

    // MARK: - Private Transform
    
    /// Transforms the input dictionary from the server to the format expected by the FIDO client.
    ///
    /// - Parameter input: The input dictionary containing FIDO authentication options.
    /// - Returns: A transformed dictionary suitable for FIDO authentication.
    func transform(_ input: [String: Any]) -> [String: Any] {
        logger.d("Transforming FIDO authentication request options")
        var output: [String: Any] = [:]
        
        if let challenge = input[FidoConstants.FIELD_CHALLENGE] as? String {
            output[FidoConstants.FIELD_CHALLENGE] = challenge
        }
        
        if let timeoutStr = input[FidoConstants.FIELD_TIMEOUT] as? String, let timeout = Int(timeoutStr) {
            output[FidoConstants.FIELD_TIMEOUT] = timeout
        }
        
        if let userVerification = input[FidoConstants.FIELD_USER_VERIFICATION] as? String {
            output[FidoConstants.FIELD_USER_VERIFICATION] = userVerification
        } else {
            output[FidoConstants.FIELD_USER_VERIFICATION] = FidoConstants.DEFAULT_USER_VERIFICATION
        }
        
        if let rpId = input[FidoConstants.FIELD_RELYING_PARTY_ID_INTERNAL] as? String {
            output[FidoConstants.FIELD_RP_ID] = rpId
        }
        
        if let allowCredentials = input[FidoConstants.FIELD_ALLOW_CREDENTIALS_INTERNAL] as? [[String: Any]] {
            output[FidoConstants.FIELD_ALLOW_CREDENTIALS] = allowCredentials.map { credential -> [String: Any] in
                var newCredential: [String: Any] = [:]
                if let type = credential[FidoConstants.FIELD_TYPE] as? String {
                    newCredential[FidoConstants.FIELD_TYPE] = type
                }
                if let idArray = credential[FidoConstants.FIELD_ID] as? [Int] {
                    let data = Data(idArray.map { UInt8(bitPattern: Int8($0)) })
                    newCredential[FidoConstants.FIELD_ID] = data.base64EncodedString()
                }
                return newCredential
            }
        }
        
        return output
    }
}
