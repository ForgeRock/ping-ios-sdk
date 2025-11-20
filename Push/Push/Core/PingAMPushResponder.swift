//
//  PingAMPushResponder.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CryptoKit
import PingLogger
import PingMfaCommons
import PingOrchestrate

/// Handles PingAM-specific network operations such as registration and authentication responses.
///
/// The responder encapsulates JWT generation, challenge response calculation, and request payload
/// creation for PingAM endpoints. Networking operations are executed using the supplied
/// `HttpClient`, while logging is delegated to the provided `Logger` instance.
public final class PingAMPushResponder: @unchecked Sendable {

    /// Shared HTTP client used for all network requests.
    private let httpClient: HttpClient

    /// Logger instance for diagnostic information.
    private let logger: Logger?

    // MARK: - Initialization

    /// Creates a new PingAM responder.
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client responsible for executing network requests.
    ///   - logger: Optional logger used for diagnostic output. Defaults to the global logger.
    public init(httpClient: HttpClient, logger: Logger? = LogManager.logger) {
        self.httpClient = httpClient
        self.logger = logger
    }

    // MARK: - Registration

    /// Registers a push credential with PingAM.
    ///
    /// - Parameters:
    ///   - credential: The credential that should be enrolled with PingAM.
    ///   - params: Additional registration parameters including challenge, messageId, and device metadata.
    /// - Returns: `true` when the registration request succeeds (HTTP 2xx).
    /// - Throws: `PushError` when required parameters are missing, the request fails, or the response is unsuccessful.
    @discardableResult
    public func register(
        credential: PushCredential,
        params: [String: Any]
    ) async throws -> Bool {
        logger?.d("Registering credential \(credential.id) with PingAM")

        let endpoint = credential.registrationEndpoint
        // Required parameters
        let messageId = try requiredParam(params, key: Keys.messageId)
        let deviceId = try requiredParam(params, key: Keys.deviceId)
        let challenge = try requiredParam(params, key: Keys.challenge)

        // Optional parameters
        let deviceName = stringParam(params, key: Keys.deviceName) ?? Constants.defaultDeviceName
        let amlbCookie = stringParam(params, key: Keys.amlbCookie)

        // Generate challenge response and JWT payload
        let challengeResponse = try generateChallengeResponse(
            base64Secret: credential.sharedSecret,
            base64Challenge: challenge
        )

        let claims = makeRegistrationClaims(
            deviceId: deviceId,
            deviceName: deviceName,
            mechanismUID: credential.id,
            challengeResponse: challengeResponse
        )

        let jwt = try generateJwt(
            base64Secret: credential.sharedSecret,
            claims: claims
        )

        // Build request body
        var requestBody: [String: Any] = [
            Keys.messageId: messageId,
            Keys.jwt: jwt
        ]

        if let userId = credential.userId, !userId.isEmpty {
            requestBody[Keys.userId] = userId
        }

        // Configure HTTP request
        let request = Request(urlString: endpoint)
        request.header(name: Constants.headerAcceptAPIVersion, value: Constants.acceptApiVersion)
        if let amlbCookie {
            request.header(name: Constants.headerCookie, value: amlbCookie)
        }
        request.body(body: requestBody)

        do {
            let (data, response) = try await httpClient.sendRequest(request: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger?.e("Registration failed: invalid response", error: nil)
                throw PushError.networkFailure("Invalid response from registration endpoint", nil)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyDescription = String(data: data, encoding: .utf8) ?? "no response body"
                let message = "Registration failed with status code \(httpResponse.statusCode): \(bodyDescription)"
                logger?.e(message, error: nil)
                throw PushError.networkFailure(message, nil)
            }

            logger?.d("Credential \(credential.id) successfully registered with PingAM")
            return true
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Registration request threw an error", error: error)
            throw PushError.networkFailure("Registration request failed", error)
        }
    }

    // MARK: - Authentication

    /// Sends an authentication decision (approve or deny) to PingAM.
    ///
    /// - Parameters:
    ///   - credential: The credential associated with the notification.
    ///   - notification: The notification being responded to.
    ///   - approve: `true` to approve, `false` to deny.
    ///   - numbersChallengeResponse: Optional user-entered response for number-matching challenges.
    /// - Returns: `true` when the request succeeds (HTTP 2xx).
    /// - Throws: `PushError` when required data is missing or the network request fails.
    @discardableResult
    public func sendAuthenticationResponse(
        credential: PushCredential,
        notification: PushNotification,
        approve: Bool,
        numbersChallengeResponse: String? = nil
    ) async throws -> Bool {
        logger?.d("Sending \(approve ? "approval" : "denial") for notification \(notification.id)")

        guard let challenge = notification.challenge, !challenge.isEmpty else {
            logger?.e("Authentication response failed: missing challenge", error: nil)
            throw PushError.invalidParameterValue("Notification challenge is required")
        }

        let challengeResponse = try generateChallengeResponse(
            base64Secret: credential.sharedSecret,
            base64Challenge: challenge
        )

        let claims = makeAuthenticationClaims(
            challengeResponse: challengeResponse,
            deny: !approve,
            numbersChallengeResponse: numbersChallengeResponse
        )

        let jwt = try generateJwt(
            base64Secret: credential.sharedSecret,
            claims: claims
        )

        var requestBody: [String: Any] = [
            Keys.messageId: notification.messageId,
            Keys.jwt: jwt
        ]

        if let userId = credential.userId, !userId.isEmpty {
            requestBody[Keys.userId] = userId
        }

        let request = Request(urlString: credential.authenticationEndpoint)
        request.header(name: Constants.headerAcceptAPIVersion, value: Constants.acceptApiVersion)
        if let amlbCookie = notification.loadBalancer, !amlbCookie.isEmpty {
            request.header(name: Constants.headerCookie, value: amlbCookie)
        }
        request.body(body: requestBody)

        do {
            let (data, response) = try await httpClient.sendRequest(request: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger?.e("Authentication response failed: invalid response", error: nil)
                throw PushError.networkFailure("Invalid response from authentication endpoint", nil)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyDescription = String(data: data, encoding: .utf8) ?? "no response body"
                let message = "Authentication response failed with status code \(httpResponse.statusCode): \(bodyDescription)"
                logger?.e(message, error: nil)
                throw PushError.networkFailure(message, nil)
            }

            logger?.d("Authentication response sent successfully for notification \(notification.id)")
            return true
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Authentication response request threw an error", error: error)
            throw PushError.networkFailure("Authentication response request failed", error)
        }
    }

    // MARK: - Device Token Updates

    /// Updates the device token registered with PingAM.
    ///
    /// - Parameters:
    ///   - credential: The credential whose device token should be refreshed.
    ///   - deviceToken: The APNs token to register.
    ///   - deviceName: Optional device name; defaults to a platform-specific value when nil.
    /// - Returns: `true` when the request succeeds (HTTP 2xx).
    /// - Throws: `PushError` when the token is invalid or the request fails.
    @discardableResult
    public func updateDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        deviceName: String? = nil
    ) async throws -> Bool {
        let trimmedToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            logger?.e("Device token update failed: empty token", error: nil)
            throw PushError.invalidParameterValue("Device token cannot be empty")
        }

        let resolvedName = deviceName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? Constants.defaultDeviceName

        logger?.d("Updating device token for credential \(credential.id)")

        let claims = makeDeviceTokenClaims(
            deviceId: trimmedToken,
            deviceName: resolvedName
        )

        let jwt = try generateJwt(
            base64Secret: credential.sharedSecret,
            claims: claims
        )

        var requestBody: [String: Any] = [
            Keys.mechanismUID: credential.id,
            Keys.jwt: jwt
        ]

        if let userId = credential.userId, !userId.isEmpty {
            requestBody[Keys.userId] = userId
        }

        let request = Request(urlString: credential.updateEndpoint)
        request.header(name: Constants.headerAcceptAPIVersion, value: Constants.acceptApiVersion)
        request.body(body: requestBody)

        do {
            let (data, response) = try await httpClient.sendRequest(request: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger?.e("Device token update failed: invalid response", error: nil)
                throw PushError.networkFailure("Invalid response from update endpoint", nil)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyDescription = String(data: data, encoding: .utf8) ?? "no response body"
                let message = "Device token update failed with status code \(httpResponse.statusCode): \(bodyDescription)"
                logger?.e(message, error: nil)
                throw PushError.networkFailure(message, nil)
            }

            logger?.d("Device token updated successfully for credential \(credential.id)")
            return true
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Device token update request threw an error", error: error)
            throw PushError.networkFailure("Device token update request failed", error)
        }
    }

    // MARK: - JWT Utilities

    /// Generates a signed JWT using the provided claims and shared secret.
    ///
    /// - Parameters:
    ///   - base64Secret: The base64-encoded shared secret for the credential.
    ///   - claims: Claims to embed inside the JWT payload.
    /// - Returns: A compact JWT string signed with HS256.
    /// - Throws: `JwtError` when the secret or claims are invalid.
    internal func generateJwt(base64Secret: String, claims: [String: Any]) throws -> String {
        do {
            let sanitizedClaims = sanitizeJSONDictionary(claims)
            let jwt = try CompactJwt.signJwtClaims(
                base64Secret: base64Secret,
                claims: sanitizedClaims
            )
            logger?.d("Generated JWT payload with \(sanitizedClaims.count) claims")
            return jwt
        } catch {
            logger?.e("Failed to generate JWT", error: error)
            throw error
        }
    }

    /// Generates a challenge response using the shared secret and challenge provided by PingAM.
    ///
    /// - Parameters:
    ///   - base64Secret: The base64-encoded shared secret for the credential.
    ///   - base64Challenge: The base64-encoded challenge from PingAM.
    /// - Returns: A base64-encoded HMAC-SHA256 response string.
    /// - Throws: `PushError.invalidParameterValue` when the secret or challenge are invalid.
    internal func generateChallengeResponse(
        base64Secret: String,
        base64Challenge: String
    ) throws -> String {
        guard !base64Secret.isEmpty else {
            logger?.e("Challenge response generation failed: secret is empty", error: nil)
            throw PushError.invalidParameterValue("Secret cannot be empty")
        }

        guard let secretData = Data(base64Encoded: base64Secret) else {
            logger?.e("Challenge response generation failed: invalid secret format", error: nil)
            throw PushError.invalidParameterValue("Invalid base64 secret")
        }

        guard let challengeData = Data(base64Encoded: base64Challenge) else {
            logger?.e("Challenge response generation failed: invalid challenge", error: nil)
            throw PushError.invalidParameterValue("Invalid base64 challenge")
        }

        let key = SymmetricKey(data: secretData)
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: challengeData,
            using: key
        )

        let response = Data(authenticationCode).base64EncodedString()
        logger?.d("Generated challenge response")
        return response
    }

    // MARK: - Payload Helpers

    /// Creates the registration claims used when enrolling a device with PingAM.
    ///
    /// - Parameters:
    ///   - deviceId: The APNs device token.
    ///   - deviceName: Friendly device name supplied by the client.
    ///   - mechanismUID: The credential identifier.
    ///   - challengeResponse: The HMAC response generated from the registration challenge.
    /// - Returns: A dictionary of claims ready to be signed inside a JWT.
    internal func makeRegistrationClaims(
        deviceId: String,
        deviceName: String,
        mechanismUID: String,
        challengeResponse: String
    ) -> [String: Any] {
        [
            Keys.deviceId: deviceId,
            Keys.deviceName: deviceName,
            Keys.deviceType: Constants.deviceType,
            Keys.communicationType: Constants.communicationType,
            Keys.mechanismUID: mechanismUID,
            Keys.response: challengeResponse
        ]
    }

    /// Creates the authentication claims used when responding to a push notification.
    ///
    /// - Parameters:
    ///   - challengeResponse: The HMAC response derived from the notification challenge.
    ///   - deny: Indicates whether the response represents a denial.
    ///   - numbersChallengeResponse: Optional user-provided response for number challenges.
    /// - Returns: A dictionary of claims ready to be signed inside a JWT.
    internal func makeAuthenticationClaims(
        challengeResponse: String,
        deny: Bool,
        numbersChallengeResponse: String?
    ) -> [String: Any] {
        var claims: [String: Any] = [
            Keys.response: challengeResponse
        ]

        if let numbersChallengeResponse {
            claims[Keys.challengeResponse] = numbersChallengeResponse
        }

        if deny {
            claims[Keys.deny] = true
        }

        return claims
    }

    /// Creates claims for device token update requests.
    ///
    /// - Parameters:
    ///   - deviceId: The APNs device token.
    ///   - deviceName: Friendly device name supplied by the client.
    /// - Returns: A dictionary of claims ready to be signed inside a JWT.
    internal func makeDeviceTokenClaims(
        deviceId: String,
        deviceName: String
    ) -> [String: Any] {
        [
            Keys.deviceId: deviceId,
            Keys.deviceName: deviceName,
            Keys.deviceType: Constants.deviceType,
            Keys.communicationType: Constants.communicationType
        ]
    }

    /// Encodes a dictionary as JSON data suitable for HTTP payloads.
    ///
    /// - Parameter body: The body to encode.
    /// - Returns: JSON data representation of the provided body.
    /// - Throws: `PushError.invalidParameterValue` if the body cannot be encoded as JSON.
    internal func encodeRequestBody(_ body: [String: Any]) throws -> Data {
        let sanitized = sanitizeJSONDictionary(body)
        do {
            return try JSONSerialization.data(withJSONObject: sanitized, options: [])
        } catch {
            logger?.e("Failed to encode request body as JSON", error: error)
            throw PushError.invalidParameterValue(
                "Unable to encode request body: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - JSON Sanitisation

    private func sanitizeJSONDictionary(_ dictionary: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        for (key, value) in dictionary {
            sanitized[key] = sanitizeJSONValue(value)
        }
        return sanitized
    }

    private func sanitizeJSONValue(_ value: Any) -> Any {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let array as [Any]:
            return array.map { sanitizeJSONValue($0) }
        case let dict as [String: Any]:
            return sanitizeJSONDictionary(dict)
        case is NSNull:
            return NSNull()
        default:
            return String(describing: value)
        }
    }

    // MARK: - Internal Constants

    internal enum Keys {
        static let messageId = "messageId"
        static let mechanismUID = "mechanismUid"
        static let response = "response"
        static let deny = "deny"
        static let challengeResponse = "challengeResponse"
        static let communicationType = "communicationType"
        static let deviceId = "deviceId"
        static let deviceName = "deviceName"
        static let deviceType = "deviceType"
        static let amlbCookie = "amlbCookie"
        static let challenge = "challenge"
        static let jwt = "jwt"
        static let userId = "userId"
    }

    private enum Constants {
        static let acceptApiVersion = "resource=1.0, protocol=1.0"
        static let applicationJson = "application/json"
        static let headerContentType = "Content-Type"
        static let headerAcceptAPIVersion = "Accept-API-Version"
        static let headerCookie = "Cookie"
        static let deviceType = "ios"
        static let communicationType = "apns"
        static let responseAlgorithm = "HmacSHA256"
        static let defaultDeviceName = "iOS Device"
    }

    // MARK: - Parameter Helpers

    private func stringParam(_ params: [String: Any], key: String) -> String? {
        guard let rawValue = params[key] else { return nil }
        if let string = rawValue as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let description = String(describing: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    private func requiredParam(_ params: [String: Any], key: String) throws -> String {
        if let value = stringParam(params, key: key) {
            return value
        }
        logger?.e("Missing required parameter: \(key)", error: nil)
        throw PushError.missingRequiredParameter(key)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
