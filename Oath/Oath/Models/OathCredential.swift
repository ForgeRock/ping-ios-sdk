//
//  OathCredential.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents an OATH (TOTP/HOTP) credential.
/// This model holds all necessary information to generate OTP codes and identify the credential.
///
/// - Note: The secret key is stored securely and not exposed in the public API.
public struct OathCredential: Codable, Identifiable, Sendable, CustomStringConvertible, CustomReflectable {

    /// Unique identifier for the credential (local ID).
    public let id: String

    /// User identifier on the server.
    public let userId: String?

    /// Server-side device identifier.
    public let resourceId: String?

    /// The name of the issuer for this credential.
    public let issuer: String

    /// The name of the issuer for this credential, editable by the user.
    public var displayIssuer: String

    /// The account name (username) associated with this credential.
    public let accountName: String

    /// The account name (username) associated with this credential, editable by the user.
    public var displayAccountName: String

    /// The type of credential (TOTP or HOTP).
    public let oathType: OathType

    /// The HMAC algorithm used (SHA1, SHA256, SHA512).
    public let oathAlgorithm: OathAlgorithm

    /// The number of digits in the generated codes.
    public let digits: Int

    /// For TOTP, the time period in seconds for which a code is valid.
    public let period: Int

    /// For HOTP, the counter value used to generate the next code.
    public var counter: Int

    /// The timestamp when this credential was created.
    public let createdAt: Date

    /// Optional URL for the issuer's logo or image.
    public let imageURL: String?

    /// Optional background color for the credential.
    public let backgroundColor: String?

    /// Optional Authenticator Policies in a JSON String format for the credential.
    public let policies: String?

    /// Optional name of the Policy locking the credential.
    public var lockingPolicy: String?

    /// Indicates whether the credential is locked.
    public var isLocked: Bool

    /// The secret key for code generation. This is stored internally and never exposed.
    internal let secretKey: String

    // MARK: - Computed Properties

    /// String representation of the OATH type.
    public var type: String { oathType.rawValue }

    /// String representation of the OATH algorithm.
    public var algorithm: String { oathAlgorithm.rawValue }


    // MARK: - Initializers

    /// Creates a new OATH credential.
    /// - Parameters:
    ///   - id: Unique identifier for the credential. Defaults to a new UUID.
    ///   - userId: User identifier on the server.
    ///   - resourceId: Server-side device identifier.
    ///   - issuer: The name of the issuer for this credential.
    ///   - displayIssuer: The display name of the issuer, editable by the user.
    ///   - accountName: The account name associated with this credential.
    ///   - displayAccountName: The display account name, editable by the user.
    ///   - oathType: The type of credential (TOTP or HOTP).
    ///   - oathAlgorithm: The HMAC algorithm used.
    ///   - digits: The number of digits in generated codes. Defaults to 6.
    ///   - period: For TOTP, the time period in seconds. Defaults to 30.
    ///   - counter: For HOTP, the counter value. Defaults to 0.
    ///   - createdAt: The creation timestamp. Defaults to current date.
    ///   - imageURL: Optional URL for the issuer's image.
    ///   - backgroundColor: Optional background color.
    ///   - policies: Optional policies in JSON format.
    ///   - lockingPolicy: Optional locking policy name.
    ///   - isLocked: Whether the credential is locked. Defaults to false.
    ///   - secretKey: The secret key for OTP generation.
    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        resourceId: String? = nil,
        issuer: String,
        displayIssuer: String? = nil,
        accountName: String,
        displayAccountName: String? = nil,
        oathType: OathType,
        oathAlgorithm: OathAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: Int = 0,
        createdAt: Date = Date(),
        imageURL: String? = nil,
        backgroundColor: String? = nil,
        policies: String? = nil,
        lockingPolicy: String? = nil,
        isLocked: Bool = false,
        secretKey: String
    ) {
        self.id = id
        self.userId = userId
        self.resourceId = resourceId
        self.issuer = issuer
        self.displayIssuer = displayIssuer ?? issuer
        self.accountName = accountName
        self.displayAccountName = displayAccountName ?? accountName
        self.oathType = oathType
        self.oathAlgorithm = oathAlgorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.createdAt = createdAt
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.policies = policies
        self.lockingPolicy = lockingPolicy
        self.isLocked = isLocked
        self.secretKey = secretKey
    }

    
    // MARK: - Factory Methods

    /// Creates an OATH credential from a URI string.
    /// - Parameter uri: The URI string to parse.
    /// - Returns: A new OathCredential instance.
    /// - Throws: `OathError.invalidUri` if the URI is malformed.
    public static func fromUri(_ uri: String) async throws -> OathCredential {
        return try await OathUriParser.parse(uri)
    }

    /// Converts this credential to a URI string.
    /// - Returns: A URI string representation of this credential.
    /// - Throws: `OathError.uriFormatting` if formatting fails.
    public func toUri() async throws -> String {
        return try await OathUriParser.format(self)
    }

    
    // MARK: - Policy Methods
    
    /// Lock this credential due to policy violations.
    ///
    /// Locked credentials cannot be used for code generation until they are unlocked.
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
    /// to be used for code generation again.
    public mutating func unlockCredential() {
        isLocked = false
        lockingPolicy = nil
    }

    
    // MARK: - Validation

    /// Validates the credential parameters.
    /// - Throws: `OathError.invalidParameterValue` if any parameter is invalid.
    internal func validate() throws {
        // Validate digits
        guard digits >= 4 && digits <= 8 else {
            throw OathError.invalidParameterValue("Digits must be between 4 and 8")
        }

        // Validate period for TOTP
        if oathType == .totp {
            guard period > 0 && period <= 300 else {
                throw OathError.invalidParameterValue("Period must be between 1 and 300 seconds")
            }
        }

        // Validate counter for HOTP
        if oathType == .hotp {
            guard counter >= 0 else {
                throw OathError.invalidParameterValue("Counter must be non-negative")
            }
        }

        // Validate secret key is not empty and within length limits
        guard !secretKey.isEmpty else {
            throw OathError.invalidSecret("Secret key cannot be empty")
        }

        guard secretKey.count <= OathUriParser.maxSecretLength else {
            throw OathError.invalidSecret("Secret key exceeds maximum length of \(OathUriParser.maxSecretLength)")
        }

        // Validate issuer is not empty and within length limits
        guard !issuer.isEmpty else {
            throw OathError.invalidParameterValue("Issuer cannot be empty")
        }
        
        guard issuer.count <= OathUriParser.maxParameterLength else {
            throw OathError.invalidParameterValue("Issuer exceeds maximum length of \(OathUriParser.maxParameterLength)")
        }

        // Validate account name is not empty and within length limits
        guard !accountName.isEmpty else {
            throw OathError.invalidParameterValue("Account name cannot be empty")
        }
        
        guard accountName.count <= OathUriParser.maxParameterLength else {
            throw OathError.invalidParameterValue("Account name exceeds maximum length of \(OathUriParser.maxParameterLength)")
        }
    }

    
    // MARK: - Codable Implementation

    /// Coding keys for JSON serialization, excluding the secret key for security.
    ///
    /// This credential uses Swift's standard `Codable` protocol for JSON serialization.
    /// You can use `JSONEncoder` and `JSONDecoder` directly:
    /// ```swift
    /// // Encoding
    /// let encoder = JSONEncoder()
    /// let data = try encoder.encode(credential)
    ///
    /// // Decoding (note: secret key must be loaded separately from secure storage)
    /// let decoder = JSONDecoder()
    /// let credential = try decoder.decode(OathCredential.self, from: data)
    /// ```
    ///
    /// - Important: The secret key is never included in JSON serialization for security reasons.
    ///   It must be stored and retrieved separately using secure storage.
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case resourceId
        case issuer
        case displayIssuer
        case accountName
        case displayAccountName
        case oathType
        case oathAlgorithm
        case digits
        case period
        case counter
        case createdAt
        case imageURL
        case backgroundColor
        case policies
        case lockingPolicy
        case isLocked
        // Note: secretKey is intentionally not included for security reasons
    }

    /// Custom initializer for decoding. The secret key must be provided separately.
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if decoding fails.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        issuer = try container.decode(String.self, forKey: .issuer)
        displayIssuer = try container.decode(String.self, forKey: .displayIssuer)
        accountName = try container.decode(String.self, forKey: .accountName)
        displayAccountName = try container.decode(String.self, forKey: .displayAccountName)
        oathType = try container.decode(OathType.self, forKey: .oathType)
        oathAlgorithm = try container.decode(OathAlgorithm.self, forKey: .oathAlgorithm)
        digits = try container.decode(Int.self, forKey: .digits)
        period = try container.decode(Int.self, forKey: .period)
        counter = try container.decode(Int.self, forKey: .counter)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        policies = try container.decodeIfPresent(String.self, forKey: .policies)
        lockingPolicy = try container.decodeIfPresent(String.self, forKey: .lockingPolicy)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)

        // Secret key must be provided separately for security reasons
        // This should be loaded from secure storage by the storage layer
        self.secretKey = ""
    }

    /// Custom encoder implementation that excludes the secret key.
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(displayIssuer, forKey: .displayIssuer)
        try container.encode(accountName, forKey: .accountName)
        try container.encode(displayAccountName, forKey: .displayAccountName)
        try container.encode(oathType, forKey: .oathType)
        try container.encode(oathAlgorithm, forKey: .oathAlgorithm)
        try container.encode(digits, forKey: .digits)
        try container.encode(period, forKey: .period)
        try container.encode(counter, forKey: .counter)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(policies, forKey: .policies)
        try container.encodeIfPresent(lockingPolicy, forKey: .lockingPolicy)
        try container.encode(isLocked, forKey: .isLocked)

        // Note: secretKey is intentionally not encoded for security reasons
    }
    
    /// A textual description of the credential, excluding the secret key.
    public var description: String {
        return "\(issuer):\(accountName) (\(type))"
    }

    
    // MARK: - CustomStringConvertible & CustomReflectable
    
    /// Custom reflection for the credential, excluding the secret key.
    public var customMirror: Mirror {
        return Mirror(self, children: [
            "id": id,
            "userId": userId as Any,
            "resourceId": resourceId as Any,
            "issuer": issuer,
            "displayIssuer": displayIssuer,
            "accountName": accountName,
            "displayAccountName": displayAccountName,
            "oathType": oathType,
            "oathAlgorithm": oathAlgorithm,
            "digits": digits,
            "period": period,
            "counter": counter,
            "createdAt": createdAt,
            "imageURL": imageURL as Any,
            "backgroundColor": backgroundColor as Any,
            "policies": policies as Any,
            "lockingPolicy": lockingPolicy as Any,
            "isLocked": isLocked
            // Note: secretKey is intentionally not included for security reasons
        ])
    }

}


// MARK: - Internal Extensions

internal extension OathCredential {
    /// Creates a credential with a secret key for internal use.
    /// This method is used by the storage layer to reconstruct credentials with their secrets.
    /// - Parameters:
    ///   - credential: The base credential without secret.
    ///   - secretKey: The secret key to associate with the credential.
    /// - Returns: A new credential with the secret key.
    static func withSecret(_ credential: OathCredential, secretKey: String) -> OathCredential {
        return OathCredential(
            id: credential.id,
            userId: credential.userId,
            resourceId: credential.resourceId,
            issuer: credential.issuer,
            displayIssuer: credential.displayIssuer,
            accountName: credential.accountName,
            displayAccountName: credential.displayAccountName,
            oathType: credential.oathType,
            oathAlgorithm: credential.oathAlgorithm,
            digits: credential.digits,
            period: credential.period,
            counter: credential.counter,
            createdAt: credential.createdAt,
            imageURL: credential.imageURL,
            backgroundColor: credential.backgroundColor,
            policies: credential.policies,
            lockingPolicy: credential.lockingPolicy,
            isLocked: credential.isLocked,
            secretKey: secretKey
        )
    }

    /// Returns the secret key for internal operations.
    /// This should only be used by the algorithm helper and storage implementations.
    var secret: String {
        return secretKey
    }
}
