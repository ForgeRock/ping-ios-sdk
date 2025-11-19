//
//  PingAMPushHandler.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingMfaCommons
import PingOrchestrate

/// Protocol defining the operations required to respond to PingAM push notifications.
/// This protocol is implemented by `PingAMPushResponder` and can be mocked for testing
/// purposes.
public protocol PingAMPushResponderType: Sendable {
    @discardableResult
    func register(credential: PushCredential, params: [String: Any]) async throws -> Bool

    @discardableResult
    func sendAuthenticationResponse(
        credential: PushCredential,
        notification: PushNotification,
        approve: Bool,
        numbersChallengeResponse: String?
    ) async throws -> Bool

    @discardableResult
    func updateDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        deviceName: String?
    ) async throws -> Bool
}

extension PingAMPushResponder: PingAMPushResponderType {}

/// PingAM implementation of the `PushHandler` protocol.
///
/// This handler is responsible for determining whether an incoming push message belongs to
/// PingAM and for parsing the payload into a normalized dictionary that can be consumed by the
/// Push service layer. Network operations (registration, approvals, etc.) are delegated to
/// `PingAMPushResponder` and completed in subsequent phases of the implementation plan.
public final class PingAMPushHandler: PushHandler, @unchecked Sendable {

    // MARK: - Internal Constants

    enum Keys {
        static let messageId = "messageId"
        static let message = "message"
        static let rawJwt = "rawJwt"
        static let credentialId = "credentialId"
        static let challenge = "challenge"
        static let ttl = "ttl"
        static let timeInterval = "timeInterval"
        static let messageText = "messageText"
        static let customPayload = "customPayload"
        static let numbersChallenge = "numbersChallenge"
        static let contextInfo = "contextInfo"
        static let amlbCookie = "amlbCookie"
        static let pushType = "pushType"
        static let userId = "userId"
        static let additionalData = "additionalData"
        static let deviceName = "deviceName"
    }

    private enum JwtClaims {
        static let mechanismUID = "u"
        static let challenge = "c"
        static let ttl = "t"
        static let timeInterval = "i"
        static let messageText = "m"
        static let pushType = "k"
        static let customPayload = "p"
        static let numbersChallenge = "n"
        static let contextInfo = "x"
        static let amlbCookie = "l"
        static let userId = "d"
        static let deviceName = "e"
    }

    private enum Constants {
        static let defaultTtl = 120
        static let messageKey = "message"
        static let defaultDeviceName = "iOS Device"
    }

    // MARK: - Properties

    private let logger: Logger?
    private let pushResponder: PingAMPushResponderType

    // MARK: - Initialization

    /// Creates a new PingAM handler.
    ///
    /// - Parameters:
    ///   - httpClient: HTTP client used by the responder.
    ///   - logger: Optional logger for diagnostics.
    ///   - pushResponder: Optional responder override (useful for testing).
    public init(
        httpClient: HttpClient,
        logger: Logger? = LogManager.logger,
        pushResponder: PingAMPushResponderType? = nil
    ) {
        self.logger = logger
        self.pushResponder = pushResponder ?? PingAMPushResponder(httpClient: httpClient, logger: logger)
    }

    // MARK: - PushHandler Conformance (Message Detection)

    /// Check if this handler can process the given message.
    ///
    /// - Parameter messageData: The raw message data dictionary.
    /// - Returns: `true` if the message can be handled; `false` otherwise
    public func canHandle(messageData: [String: Any]) -> Bool {
        guard
            let messageId = messageData[Keys.messageId] as? String,
            !messageId.isEmpty,
            let message = messageData[Constants.messageKey] as? String,
            !message.isEmpty
        else {
            logger?.w("PingAMPushHandler cannot handle message: missing messageId or message payload", error: nil)
            return false
        }

        return isValidJwt(message)
    }

    /// Check if this handler can process the given message.
    ///
    /// - Parameter message: The raw message string.
    /// - Returns: `true` if the message can be handled; `false` otherwise
    public func canHandle(message: String) -> Bool {
        isValidJwt(message)
    }

    // MARK: - PushHandler Conformance (Message Parsing)

    /// Parse a PingAM push notification message data into a normalized dictionary.
    ///
    /// - Parameter messageData: The raw message data dictionary.
    /// - Returns: A dictionary containing the parsed message fields.
    public func parseMessage(messageData: [String: Any]) throws -> [String: Any] {
        guard
            let messageId = messageData[Keys.messageId] as? String,
            let rawMessage = messageData[Constants.messageKey] as? String
        else {
            logger?.e("PingAMPushHandler received invalid message data", error: nil)
            throw PushError.messageParsingFailed("Missing required message or messageId")
        }

        return try parseJwtMessage(jwt: rawMessage, messageId: messageId)
    }

    /// Parse a PingAM push notification message string into a normalized dictionary.
    ///
    /// - Parameter message: The raw message string.
    /// - Returns: A dictionary containing the parsed message fields.
    public func parseMessage(message: String) throws -> [String: Any] {
        let signatureFragment = message.split(separator: ".").last.map(String.init) ?? UUID().uuidString
        let messageId = String(signatureFragment.prefix(8))
        return try parseJwtMessage(jwt: message, messageId: messageId)
    }

    // MARK: - PushHandler Conformance (Operations - Implemented in later tasks)

    /// Send approval for a PingAM push notification.
    ///
    /// - Parameters:
    ///   - credential: The push credential associated with the notification.
    ///   - notification: The push notification to approve.
    ///   - params: Additional parameters for the approval.
    /// - Returns: `true` if the approval was sent successfully; `false` otherwise.
    public func sendApproval(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        let numbersResponse = params["challengeResponse"] as? String

        if notification.pushType == .challenge {
            guard let numbersResponse, !numbersResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                logger?.w("Missing challenge response for challenge push notification", error: nil)
                throw PushError.invalidParameterValue("Challenge response is required for challenge notifications")
            }
        }

        let trimmedResponse = numbersResponse?.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try await pushResponder.sendAuthenticationResponse(
            credential: credential,
            notification: notification,
            approve: true,
            numbersChallengeResponse: trimmedResponse
        )

        logger?.d("sendApproval result: \(result)")
        return result
    }

    /// Send denial for a PingAM push notification.
    ///
    /// - Parameters:
    ///   - credential: The push credential associated with the notification.
    ///   - notification: The push notification to deny.
    ///   - params: Additional parameters for the denial.
    /// - Returns: `true` if the denial was sent successfully; `false` otherwise
    public func sendDenial(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool {
        let result = try await pushResponder.sendAuthenticationResponse(
            credential: credential,
            notification: notification,
            approve: false,
            numbersChallengeResponse: nil
        )

        logger?.d("sendDenial result: \(result)")
        return result
    }

    /// Set or update the device token for push notifications.
    ///
    /// - Parameters:
    ///   - credential: The push credential associated with the device.
    ///   - deviceToken: The device token string.
    ///   - params: Additional parameters, including optional device name.
    /// - Returns: `true` if the device token was set successfully; `false` otherwise.
    public func setDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        params: [String: Any]
    ) async throws -> Bool {
        let trimmedToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            logger?.w("Device token cannot be empty", error: nil)
            throw PushError.invalidParameterValue("Device token cannot be empty")
        }

        let resolvedName = (params[Keys.deviceName] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? Constants.defaultDeviceName

        let result = try await pushResponder.updateDeviceToken(
            credential: credential,
            deviceToken: trimmedToken,
            deviceName: resolvedName
        )

        logger?.d("setDeviceToken result: \(result)")
        return result
    }

    /// Register the push credential with PingAM.
    ///
    /// - Parameters:
    ///   - credential: The push credential to register.
    ///   - params: Additional registration parameters.
    /// - Returns: `true` if registration was successful; `false` otherwise.
    public func register(
        credential: PushCredential,
        params: [String: Any]
    ) async throws -> Bool {
        guard !params.isEmpty else {
            logger?.w("register called without parameters", error: nil)
            throw PushError.invalidParameterValue("PingAM registration parameters cannot be empty")
        }

        let result = try await pushResponder.register(
            credential: credential,
            params: params
        )

        logger?.d("register result: \(result)")
        return result
    }

    // MARK: - JWT Utilities

    private func isValidJwt(_ jwt: String) -> Bool {
        let isValid = CompactJwt.canParseJwt(
            jwt,
            requiredFields: [JwtClaims.mechanismUID, JwtClaims.challenge]
        )

        if !isValid {
            logger?.w("PingAMPushHandler received invalid JWT", error: nil)
        }

        return isValid
    }

    private func parseJwtMessage(jwt: String, messageId: String) throws -> [String: Any] {
        var result: [String: Any] = [
            Keys.messageId: messageId,
            Keys.rawJwt: jwt
        ]

        do {
            let claims = try CompactJwt.parseJwtClaims(jwt)

            if let credentialId = claims[JwtClaims.mechanismUID] {
                result[Keys.credentialId] = credentialId
            }

            if let challenge = claims[JwtClaims.challenge] as? String {
                result[Keys.challenge] = challenge
            }

            result[Keys.ttl] = parseInteger(claims[JwtClaims.ttl], defaultValue: Constants.defaultTtl)

            if let timeInterval = parseInteger(claims[JwtClaims.timeInterval], defaultValue: nil) {
                result[Keys.timeInterval] = timeInterval
            }

            if let messageText = claims[JwtClaims.messageText] {
                result[Keys.messageText] = messageText
            }

            if let customPayload = claims[JwtClaims.customPayload] {
                result[Keys.customPayload] = customPayload
            }

            if let numbers = claims[JwtClaims.numbersChallenge] {
                result[Keys.numbersChallenge] = numbers
            }

            if let contextInfo = claims[JwtClaims.contextInfo] {
                result[Keys.contextInfo] = contextInfo
            }

            if let pushType = claims[JwtClaims.pushType] {
                result[Keys.pushType] = pushType
            }

            if let userId = claims[JwtClaims.userId] {
                result[Keys.userId] = userId
            }

            if let deviceName = claims[JwtClaims.deviceName] {
                result[Keys.deviceName] = deviceName
            }

            if let amlbCookie = claims[JwtClaims.amlbCookie] as? String,
               let decoded = Data(base64Encoded: amlbCookie) {
                result[Keys.amlbCookie] = String(data: decoded, encoding: .utf8) ?? amlbCookie
            }

            let additional = claims.filter { key, _ in
                ![
                    JwtClaims.mechanismUID,
                    JwtClaims.challenge,
                    JwtClaims.ttl,
                    JwtClaims.timeInterval,
                    JwtClaims.messageText,
                    JwtClaims.customPayload,
                    JwtClaims.numbersChallenge,
                    JwtClaims.contextInfo,
                    JwtClaims.amlbCookie,
                    JwtClaims.pushType,
                    JwtClaims.userId,
                    JwtClaims.deviceName
                ].contains(key)
            }

            result[Keys.additionalData] = additional

            logger?.d("Parsed PingAM push message with id \(messageId)")
            return result
        } catch {
            logger?.e("Failed to parse PingAM JWT payload", error: error)
            throw PushError.messageParsingFailed("Unable to parse PingAM message: \(error.localizedDescription)")
        }
    }

    private func parseInteger(_ value: Any?, defaultValue: Int?) -> Int? {
        guard let value else { return defaultValue }

        if let intValue = value as? Int {
            return intValue
        }

        if let stringValue = value as? String, let parsed = Int(stringValue) {
            return parsed
        }

        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return defaultValue
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
