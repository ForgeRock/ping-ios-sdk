//
//  PushNotification.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents a push notification authentication challenge.
///
/// A Push notification contains all the information about an authentication request
/// received via push notification. It includes the notification content, challenge data,
/// expiration information, and response status.
///
/// ## Notification Types
///
/// Push notifications can be of different types:
/// - **DEFAULT**: Simple approve/deny notification
/// - **CHALLENGE**: Notification requiring challenge verification (e.g., number matching)
/// - **BIOMETRIC**: Notification requiring biometric authentication
///
/// ## Lifecycle
///
/// 1. **Created**: Notification is received and stored
/// 2. **Pending**: Waiting for user action
/// 3. **Approved/Denied**: User has responded
/// 4. **Expired**: TTL has elapsed
///
/// ## Usage Example
///
/// ```swift
/// // Process incoming notification
/// let notification = try await client.processNotification(userInfo)
///
/// // Check if expired
/// if notification.isExpired {
///     print("Notification has expired")
///     return
/// }
///
/// // For challenge notifications, get the numbers
/// if notification.pushType == .challenge {
///     let numbers = notification.getNumbersChallenge()
///     // Display numbers to user
/// }
///
/// // Approve or deny
/// try await client.approveNotification(notification.id)
/// ```
///
/// - Note: Notifications have a time-to-live (TTL) and can expire.
public struct PushNotification: Codable, Identifiable, @unchecked Sendable, CustomStringConvertible {
    
    // MARK: - Properties
    
    /// Unique identifier for this notification.
    public let id: String
    
    /// The ID of the associated credential.
    public let credentialId: String
    
    /// Time to live in seconds for this notification.
    /// After this period elapses, the notification is considered expired.
    public let ttl: Int
    
    /// Message ID from the push provider.
    /// This is used to correlate the notification with server records.
    public let messageId: String
    
    /// Optional message to display to the user.
    /// This typically contains context about the authentication request
    /// (e.g., "Login attempt from Chrome on Windows").
    public let messageText: String?
    
    /// Optional additional custom payload data.
    public let customPayload: String?
    
    /// Optional challenge data (e.g., verification code).
    /// Used for CHALLENGE type notifications.
    public let challenge: String?
    
    /// Optional challenge with numeric format.
    /// Typically a comma-separated list of numbers for number matching challenges.
    public var numbersChallenge: String?
    
    /// Optional cookie for load balancing.
    /// Used to route the request to the correct server in PingAM.
    public let loadBalancer: String?
    
    /// Optional additional context information.
    /// In PingAM, this may contain details such as IP address, user agent, location, etc.
    public let contextInfo: String?
    
    /// The type of push notification (DEFAULT, CHALLENGE, BIOMETRIC).
    public let pushType: PushType
    
    /// Timestamp when this notification was created locally.
    public let createdAt: Date
    
    /// Optional timestamp from the server when this notification was sent.
    public let sentAt: Date?
    
    /// Timestamp when the user responded to this notification.
    public var respondedAt: Date?
    
    /// Optional additional custom data associated with this notification.
    /// This is a map of key-value pairs. The values can be of any type.
    /// Note: This is not directly encoded/decoded due to type erasure limitations.
    public var additionalData: [String: Any]?
    
    /// Whether this notification has been approved by the user.
    public var approved: Bool
    
    /// Whether this notification is pending (not yet approved or denied).
    public var pending: Bool
    
    // MARK: - Computed Properties
    
    /// String representation of the push notification type.
    public var type: String { pushType.rawValue }
    
    /// Checks if the user has responded to this notification.
    public var responded: Bool { approved || !pending }
    
    /// Checks if this notification has expired.
    /// A notification is expired if the elapsed time since creation exceeds the TTL.
    public var isExpired: Bool {
        let elapsedTimeSeconds = Date().timeIntervalSince(createdAt)
        return elapsedTimeSeconds > Double(ttl)
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        "PushNotification(id: \(id), type: \(type), approved: \(approved), pending: \(pending), expired: \(isExpired))"
    }
    
    // MARK: - Initializers
    
    /// Creates a new Push notification.
    /// - Parameters:
    ///   - id: Unique identifier for this notification. Defaults to a new UUID.
    ///   - credentialId: The ID of the associated credential.
    ///   - ttl: Time to live in seconds for this notification.
    ///   - messageId: Message ID from the push provider.
    ///   - messageText: Optional message to display to the user.
    ///   - customPayload: Optional additional custom payload data.
    ///   - challenge: Optional challenge data.
    ///   - numbersChallenge: Optional numeric challenge.
    ///   - loadBalancer: Optional load balancer cookie.
    ///   - contextInfo: Optional context information.
    ///   - pushType: The type of push notification.
    ///   - createdAt: Timestamp when created. Defaults to current date.
    ///   - sentAt: Optional timestamp when sent by server.
    ///   - respondedAt: Optional timestamp when responded.
    ///   - additionalData: Optional additional custom data.
    ///   - approved: Whether approved. Defaults to false.
    ///   - pending: Whether pending. Defaults to true.
    public init(
        id: String = UUID().uuidString,
        credentialId: String,
        ttl: Int,
        messageId: String,
        messageText: String? = nil,
        customPayload: String? = nil,
        challenge: String? = nil,
        numbersChallenge: String? = nil,
        loadBalancer: String? = nil,
        contextInfo: String? = nil,
        pushType: PushType,
        createdAt: Date = Date(),
        sentAt: Date? = nil,
        respondedAt: Date? = nil,
        additionalData: [String: Any]? = nil,
        approved: Bool = false,
        pending: Bool = true
    ) {
        self.id = id
        self.credentialId = credentialId
        self.ttl = ttl
        self.messageId = messageId
        self.messageText = messageText
        self.customPayload = customPayload
        self.challenge = challenge
        self.numbersChallenge = numbersChallenge
        self.loadBalancer = loadBalancer
        self.contextInfo = contextInfo
        self.pushType = pushType
        self.createdAt = createdAt
        self.sentAt = sentAt
        self.respondedAt = respondedAt
        self.additionalData = additionalData
        self.approved = approved
        self.pending = pending
    }
    
    // MARK: - Action Methods
    
    /// Mark this notification as approved.
    ///
    /// This method updates the notification state to indicate that the user has
    /// approved the authentication request. It sets `approved` to true, `pending`
    /// to false, and records the response timestamp.
    public mutating func markApproved() {
        approved = true
        pending = false
        respondedAt = Date()
    }
    
    /// Mark this notification as denied.
    ///
    /// This method updates the notification state to indicate that the user has
    /// denied the authentication request. It sets `approved` to false, `pending`
    /// to false, and records the response timestamp.
    public mutating func markDenied() {
        approved = false
        pending = false
        respondedAt = Date()
    }
    
    /// Get numbers used for push challenge.
    ///
    /// For CHALLENGE type notifications, this method parses the `numbersChallenge`
    /// string (expected to be a comma-separated list of numbers) and returns them
    /// as an array of integers.
    ///
    /// - Returns: The numbers as an array of Int.
    ///            Returns empty array if numbersChallenge is not available or cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // If numbersChallenge is "12, 34, 56"
    /// let numbers = notification.getNumbersChallenge()
    /// // numbers = [12, 34, 56]
    /// ```
    public func getNumbersChallenge() -> [Int] {
        guard let challengeString = numbersChallenge else {
            return []
        }
        
        return challengeString.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case credentialId
        case ttl
        case messageId
        case messageText
        case customPayload
        case challenge
        case numbersChallenge
        case loadBalancer
        case contextInfo
        case pushType
        case createdAt
        case sentAt
        case respondedAt
        case approved
        case pending
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        credentialId = try container.decode(String.self, forKey: .credentialId)
        ttl = try container.decode(Int.self, forKey: .ttl)
        messageId = try container.decode(String.self, forKey: .messageId)
        messageText = try container.decodeIfPresent(String.self, forKey: .messageText)
        customPayload = try container.decodeIfPresent(String.self, forKey: .customPayload)
        challenge = try container.decodeIfPresent(String.self, forKey: .challenge)
        numbersChallenge = try container.decodeIfPresent(String.self, forKey: .numbersChallenge)
        loadBalancer = try container.decodeIfPresent(String.self, forKey: .loadBalancer)
        contextInfo = try container.decodeIfPresent(String.self, forKey: .contextInfo)
        pushType = try container.decode(PushType.self, forKey: .pushType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
        respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)
        approved = try container.decode(Bool.self, forKey: .approved)
        pending = try container.decode(Bool.self, forKey: .pending)
        additionalData = nil  // Not persisted in JSON
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(credentialId, forKey: .credentialId)
        try container.encode(ttl, forKey: .ttl)
        try container.encode(messageId, forKey: .messageId)
        try container.encodeIfPresent(messageText, forKey: .messageText)
        try container.encodeIfPresent(customPayload, forKey: .customPayload)
        try container.encodeIfPresent(challenge, forKey: .challenge)
        try container.encodeIfPresent(numbersChallenge, forKey: .numbersChallenge)
        try container.encodeIfPresent(loadBalancer, forKey: .loadBalancer)
        try container.encodeIfPresent(contextInfo, forKey: .contextInfo)
        try container.encode(pushType, forKey: .pushType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
        try container.encodeIfPresent(respondedAt, forKey: .respondedAt)
        try container.encode(approved, forKey: .approved)
        try container.encode(pending, forKey: .pending)
        // additionalData is not persisted in JSON
    }
}
