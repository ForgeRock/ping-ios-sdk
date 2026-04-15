//
//  PushHandler.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol that defines the required behaviour for push notification handlers.
///
/// A push handler is responsible for determining whether it can process incoming push
/// notifications for a specific platform, parsing the received payload, and delegating
/// registration and response operations to the appropriate network responder.
///
/// Implementations may interact with platform-specific services (e.g., PingAM) and are expected
/// to provide detailed logging and error handling. All methods should be thread-safe and support
/// concurrent usage from Swift concurrency contexts.
public protocol PushHandler: AnyObject, Sendable {

    /// Check if this handler can process the given message data.
    /// This method should inspect the map data (typically the push notification payload)
    /// to determine if it can be handled by this handler.
    ///
    /// - Parameter messageData: The message data as a map, usually received from UNNotification userInfo.
    /// - Returns: True if this handler can process the message data, false otherwise.
    func canHandle(messageData: [String: Any]) -> Bool

    /// Check if this handler can process the given message in string format.
    /// This method should inspect the message string to determine if it can be handled by this
    /// handler. It should return true if the handler can process the message, and false otherwise.
    ///
    /// - Parameter message: The message data as a string, typically a JWT or JSON string.
    /// - Returns: True if this handler can process the message, false otherwise.
    func canHandle(message: String) -> Bool

    /// Parse the message data received from the push service.
    /// It should extract relevant information such as notification type, message content, and any
    /// additional parameters. It should return a map of parsed data that maps to the expected
    /// structure for the PushNotification.
    ///
    /// - Parameter messageData: The message data to parse. Usually a map containing the raw data
    ///   from the push service. On iOS, this would typically come from UNNotificationRequest userInfo.
    /// - Returns: A map of parsed data.
    /// - Throws: `PushError.messageParsingFailed` if parsing fails.
    func parseMessage(messageData: [String: Any]) throws -> [String: Any]

    /// Parse the message received as a string.
    /// It should extract relevant information from the string message (typically a JWT or JSON string)
    /// and return a map of parsed data that maps to the expected structure for the PushNotification.
    ///
    /// - Parameter message: The message data as a string to parse.
    /// - Returns: A map of parsed data.
    /// - Throws: `PushError.messageParsingFailed` if parsing fails.
    func parseMessage(message: String) throws -> [String: Any]

    /// Send to the server an approval response for a notification that was received.
    /// How the approval is sent depends on the platform and the implementation of this handler.
    ///
    /// - Parameters:
    ///   - credential: The credential to use for the response.
    ///   - notification: The notification to approve.
    ///   - params: Additional parameters.
    /// - Returns: True if the approval was sent successfully, false otherwise.
    /// - Throws: `PushError.networkFailure` if the network request fails.
    func sendApproval(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool

    /// Send a denial response for a notification.
    /// How the denial is sent depends on the platform and the implementation of this handler.
    ///
    /// - Parameters:
    ///   - credential: The credential to use for the response.
    ///   - notification: The notification to deny.
    ///   - params: Additional parameters.
    /// - Returns: True if the denial was sent successfully, false otherwise.
    /// - Throws: `PushError.networkFailure` if the network request fails.
    func sendDenial(
        credential: PushCredential,
        notification: PushNotification,
        params: [String: Any]
    ) async throws -> Bool

    /// Register or update the device token.
    /// This is typically called when the device token changes.
    ///
    /// - Parameters:
    ///   - credential: The credential to register or update.
    ///   - deviceToken: The device token.
    ///   - params: Additional parameters.
    /// - Returns: True if was successful, false otherwise.
    /// - Throws: `PushError.networkFailure` if the network request fails.
    func setDeviceToken(
        credential: PushCredential,
        deviceToken: String,
        params: [String: Any]
    ) async throws -> Bool

    /// Register a new push credential with the server, if this is required by the platform.
    /// The parameters may include additional information or any other relevant data that the
    /// server needs to process the registration.
    ///
    /// - Parameters:
    ///   - credential: The credential to register.
    ///   - params: Additional parameters for registration including messageId.
    /// - Returns: True if the registration was successful, false otherwise.
    /// - Throws: `PushError.networkFailure` if the network request fails.
    func register(
        credential: PushCredential,
        params: [String: Any]
    ) async throws -> Bool
}
