//
//  PushCredential.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents a Push credential for push authentication.
///
/// A Push credential contains all the information needed to register a device for push notifications
/// and to authenticate using push challenges. This model follows the PingAM (ForgeRock) push
/// authentication protocol.
///
/// ## Credential Sources
///
/// Push credentials are typically created by:
/// - Scanning a QR code containing a `pushauth://` or `mfauth://` URI
/// - Receiving credential information from a server API
/// - Importing from backup or migration
///
/// ## Security Considerations
///
/// - The `sharedSecret` is used for cryptographic operations and must be protected
/// - Credentials can be locked based on policy violations
/// - All credential data should be stored securely in the Keychain
///
/// ## Usage Example
///
/// ```swift
/// // From QR code
/// let credential = try await PushCredential.fromUri(qrCodeUri)
///
/// // Manual creation
/// let credential = PushCredential(
///     issuer: "MyCompany",
///     accountName: "user@example.com",
///     serverEndpoint: "https://am.example.com/push",
///     sharedSecret: "base64EncodedSecret"
/// )
/// ```
public struct PushCredential: Codable, Identifiable, @unchecked Sendable, CustomStringConvertible {
    
    // MARK: - Properties
    
    /// Unique identifier for the credential (local ID).
    public let id: String
    
    /// User identifier on the server.
    public let userId: String?
    
    /// Server-side device identifier.
    /// If not provided during initialization, defaults to the credential ID.
    public let resourceId: String
    
    /// The name of the issuer for this credential.
    public let issuer: String
    
    /// The name of the issuer for this credential, editable by the user.
    public var displayIssuer: String
    
    /// The account name associated with this credential.
    public let accountName: String
    
    /// The account name associated with this credential, editable by the user.
    public var displayAccountName: String
    
    /// The endpoint where authentication responses should be sent.
    /// This is the base URL for push operations (registration, authentication, update).
    public let serverEndpoint: String
    
    /// The secret key used for cryptographic operations (JWT signing).
    /// This should be kept secure and never exposed to the user.
    internal let sharedSecret: String
    
    /// The timestamp when this credential was created.
    public let createdAt: Date
    
    /// Optional URL for the issuer's logo or image.
    public let imageURL: String?
    
    /// Optional background color for the credential (hex format).
    public let backgroundColor: String?
    
    /// Optional Authenticator Policies in a JSON String format for the credential.
    public let policies: String?
    
    /// Optional name of the Policy locking the credential.
    public var lockingPolicy: String?
    
    /// Indicates whether the credential is locked.
    public var isLocked: Bool
    
    /// The platform for which this credential is intended (e.g., PING_AM).
    public let platform: PushPlatform
    
    /// Optional additional data associated with this credential.
    /// Note: This is not directly encoded/decoded due to type erasure limitations.
    public var additionalData: [String: Any]?
    
    // MARK: - Computed Properties
    
    /// Returns the registration endpoint for this credential.
    /// This is used to register the device with the PingAM servers.
    public var registrationEndpoint: String {
        "\(serverEndpoint)?_action=register"
    }
    
    /// Returns the authentication endpoint for this credential.
    /// This is used to authenticate the user via push notification with the PingAM servers.
    public var authenticationEndpoint: String {
        "\(serverEndpoint)?_action=authenticate"
    }
    
    /// Returns the update endpoint for this credential.
    /// This is used to refresh or update the device token with the PingAM servers.
    public var updateEndpoint: String {
        "\(serverEndpoint)?_action=refresh"
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        "PushCredential(id: \(id), issuer: \(displayIssuer), account: \(displayAccountName), platform: \(platform.rawValue), locked: \(isLocked))"
    }
    
    // MARK: - Initializers
    
    /// Creates a new Push credential.
    /// - Parameters:
    ///   - id: Unique identifier for the credential. Defaults to a new UUID.
    ///   - userId: User identifier on the server.
    ///   - resourceId: Server-side device identifier. Defaults to id if not provided.
    ///   - issuer: The name of the issuer for this credential.
    ///   - displayIssuer: The display name of the issuer, editable by the user.
    ///   - accountName: The account name associated with this credential.
    ///   - displayAccountName: The display account name, editable by the user.
    ///   - serverEndpoint: The endpoint where authentication responses should be sent.
    ///   - sharedSecret: The secret key used for cryptographic operations.
    ///   - createdAt: The creation timestamp. Defaults to current date.
    ///   - imageURL: Optional URL for the issuer's image.
    ///   - backgroundColor: Optional background color.
    ///   - policies: Optional policies in JSON format.
    ///   - lockingPolicy: Optional locking policy name.
    ///   - isLocked: Whether the credential is locked. Defaults to false.
    ///   - platform: The platform for this credential. Defaults to PING_AM.
    ///   - additionalData: Optional additional data.
    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        resourceId: String? = nil,
        issuer: String,
        displayIssuer: String? = nil,
        accountName: String,
        displayAccountName: String? = nil,
        serverEndpoint: String,
        sharedSecret: String,
        createdAt: Date = Date(),
        imageURL: String? = nil,
        backgroundColor: String? = nil,
        policies: String? = nil,
        lockingPolicy: String? = nil,
        isLocked: Bool = false,
        platform: PushPlatform = .pingAM,
        additionalData: [String: Any]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.resourceId = resourceId ?? id
        self.issuer = issuer
        self.displayIssuer = displayIssuer ?? issuer
        self.accountName = accountName
        self.displayAccountName = displayAccountName ?? accountName
        self.serverEndpoint = serverEndpoint
        self.sharedSecret = sharedSecret
        self.createdAt = createdAt
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.policies = policies
        self.lockingPolicy = lockingPolicy
        self.isLocked = isLocked
        self.platform = platform
        self.additionalData = additionalData
    }
    
    // MARK: - Factory Methods
    
    /// Creates a Push credential from a URI string.
    ///
    /// This method parses a `pushauth://` or `mfauth://` URI (typically from a QR code)
    /// and creates a credential with the extracted information.
    ///
    /// - Parameter uri: The pushauth:// or mfauth:// URI string to parse.
    /// - Returns: A new PushCredential instance.
    /// - Throws: `PushError.invalidUri` if the URI is malformed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let uri = "pushauth://push/MyCompany:user@example.com?r=https://...&s=secret..."
    /// let credential = try await PushCredential.fromUri(uri)
    /// ```
    public static func fromUri(_ uri: String) async throws -> PushCredential {
        return try await PushUriParser.parse(uri)
    }
    
    /// Converts this credential to a URI string.
    ///
    /// This method creates a `pushauth://` or `mfauth://` URI that can be used
    /// to transfer or backup the credential (e.g., as a QR code).
    ///
    /// - Returns: A URI string representation of this credential.
    /// - Throws: `PushError.uriFormatting` if formatting fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let uri = try await credential.toUri()
    /// // Use uri to generate QR code for backup
    /// ```
    public func toUri() async throws -> String {
        return try await PushUriParser.format(self)
    }
    
    // MARK: - Policy Methods
    
    /// Lock this credential due to policy violations.
    ///
    /// Locked credentials cannot be used for authentication until they are unlocked.
    /// This is typically enforced by policy evaluators checking for jailbreak,
    /// device compromise, or other security violations.
    ///
    /// - Parameter policyName: The name of the policy that caused the lock.
    public mutating func lockCredential(policyName: String) {
        isLocked = true
        lockingPolicy = policyName
    }
    
    /// Unlock this credential.
    ///
    /// This removes any locking policy information and allows the credential
    /// to be used for authentication again.
    public mutating func unlockCredential() {
        isLocked = false
        lockingPolicy = nil
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case resourceId
        case issuer
        case displayIssuer
        case accountName
        case displayAccountName
        case serverEndpoint
        case sharedSecret
        case createdAt
        case imageURL
        case backgroundColor
        case policies
        case lockingPolicy
        case isLocked
        case platform
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        resourceId = try container.decode(String.self, forKey: .resourceId)
        issuer = try container.decode(String.self, forKey: .issuer)
        displayIssuer = try container.decode(String.self, forKey: .displayIssuer)
        accountName = try container.decode(String.self, forKey: .accountName)
        displayAccountName = try container.decode(String.self, forKey: .displayAccountName)
        serverEndpoint = try container.decode(String.self, forKey: .serverEndpoint)
        sharedSecret = try container.decode(String.self, forKey: .sharedSecret)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        policies = try container.decodeIfPresent(String.self, forKey: .policies)
        lockingPolicy = try container.decodeIfPresent(String.self, forKey: .lockingPolicy)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        platform = try container.decode(PushPlatform.self, forKey: .platform)
        additionalData = nil  // Not persisted in JSON
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(resourceId, forKey: .resourceId)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(displayIssuer, forKey: .displayIssuer)
        try container.encode(accountName, forKey: .accountName)
        try container.encode(displayAccountName, forKey: .displayAccountName)
        try container.encode(serverEndpoint, forKey: .serverEndpoint)
        try container.encode(sharedSecret, forKey: .sharedSecret)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(policies, forKey: .policies)
        try container.encodeIfPresent(lockingPolicy, forKey: .lockingPolicy)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(platform, forKey: .platform)
        // additionalData is not persisted in JSON
    }
}
