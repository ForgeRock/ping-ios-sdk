//
//  SSOToken.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// A protocol representing a Single Sign-On (SSO) token with session information.
///
/// `SSOToken` extends the `Session` protocol to provide additional authentication
/// context including the success URL and realm. Types conforming to this protocol
/// can be used throughout the Journey framework for session management and storage.
///
/// Conforming types must be both `Codable` (for serialization/deserialization)
/// and inherit from `Session` (providing the session value).
///
/// - SeeAlso: ``SSOTokenImpl`` for the concrete implementation
/// - SeeAlso: ``SessionConfig`` for configuring SSO token storage
public protocol SSOToken: Session, Codable {
    /// The URL to redirect to upon successful authentication.
    ///
    /// This URL represents the endpoint where the user should be directed
    /// after a successful authentication flow. It's typically provided by
    /// the authentication server as part of the success response.
    var successUrl: String { get }
    
    /// The authentication realm or domain.
    ///
    /// The realm identifies the authentication context or tenant. This is
    /// particularly important in multi-tenant scenarios where different
    /// realms may have different authentication policies or user stores.
    ///
    /// ## Example Values
    /// - `"alpha"` - A specific realm name
    /// - `"/"` - Root realm
    /// - `"customers"` - A customer-facing realm
    var realm: String { get }
}

/// A concrete implementation of ``SSOToken`` used for session storage and management.
///
/// `SSOTokenImpl` provides the standard implementation of an SSO token within the
/// Journey framework. It encapsulates all necessary information about an authenticated
/// session, including the session value, success URL, and authentication realm.
///
/// ## Storage and Persistence
///
/// This class is designed to work seamlessly with the storage layer:
/// - Conforms to `Codable` for JSON serialization to Keychain or other storage
/// - Marked as `Sendable` for safe concurrent access across actor boundaries
/// - Immutable properties ensure thread-safe usage
///
/// ## Usage in Journey Framework
///
/// `SSOTokenImpl` instances are typically created internally by the Journey framework
/// during authentication flows. However, you can also create instances manually for
/// testing or custom authentication scenarios:
///
/// ```swift
/// let token = SSOTokenImpl(
///     value: "session_token_abc123",
///     successUrl: "https://example.com/success",
///     realm: "alpha"
/// )
///
/// // Store the token
/// let storage = KeychainStorage<SSOTokenImpl>(
///     account: "my_sessions",
///     encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
/// )
/// try await storage.save(item: token)
///
/// // Retrieve the token later
/// let retrievedToken = try await storage.get()
/// print(retrievedToken?.value) // "session_token_abc123"
/// ```
///
/// ## Integration with SessionConfig
///
/// `SSOTokenImpl` is the type parameter for ``SessionConfig``'s storage property:
///
/// ```swift
/// let sessionConfig = SessionConfig()
/// // sessionConfig.storage is of type Storage<SSOTokenImpl>
///
/// // Custom storage for a specific user
/// sessionConfig.storage = KeychainStorage<SSOTokenImpl>(
///     account: "user_sessions",
///     encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
/// )
/// ```
///
/// - Important: All properties are immutable (`let`) to ensure thread safety
///   and prevent accidental modification after creation.
///
/// - Note: This class is marked as `final` to prevent subclassing, ensuring
///   the implementation remains consistent across the framework.
///
/// - SeeAlso: ``SSOToken`` for the protocol definition
/// - SeeAlso: ``SessionConfig`` for configuring session storage
public final class SSOTokenImpl: SSOToken, Sendable, Codable {
    /// The session token value.
    ///
    /// This is the actual session identifier or token string provided by the
    /// authentication server. It's used to maintain the authenticated session
    /// and is typically sent with subsequent requests to prove authentication.
    public let value: String
    
    /// The URL to redirect to upon successful authentication.
    ///
    /// After authentication completes successfully, the application should
    /// navigate to this URL. This is provided by the authentication server
    /// as part of the success response.
    public let successUrl: String
    
    /// The authentication realm or domain.
    ///
    /// Identifies the authentication context or tenant for this session.
    /// This is particularly important in multi-tenant deployments where
    /// different realms may represent different organizations or user stores.
    public let realm: String

    /// Creates a new SSO token with the specified session information.
    ///
    /// Use this initializer to create SSO token instances for authentication
    /// flows, testing, or when manually managing session state.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let token = SSOTokenImpl(
    ///     value: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    ///     successUrl: "https://app.example.com/dashboard",
    ///     realm: "customers"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - value: The session token value. This should be the session identifier
    ///     or token string provided by your authentication server.
    ///   - successUrl: The URL to navigate to after successful authentication.
    ///     This should be a valid, absolute URL string.
    ///   - realm: The authentication realm or domain. This identifies the
    ///     authentication context for the session.
    public init(value: String, successUrl: String, realm: String) {
        self.value = value
        self.successUrl = successUrl
        self.realm = realm
    }

    // MARK: - Codable Conformance
    
    /// Coding keys for encoding and decoding SSO token properties.
    ///
    /// These keys map the Swift property names to their JSON representation
    /// for serialization to and from storage.
    enum CodingKeys: String, CodingKey {
        case value
        case successUrl
        case realm
    }

    /// Creates a new SSO token by decoding from the given decoder.
    ///
    /// This initializer is used automatically when decoding SSO tokens from
    /// storage (e.g., Keychain, UserDefaults, or other persistence layers).
    /// You typically don't call this directly; instead, use standard decoding:
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// let token = try decoder.decode(SSOTokenImpl.self, from: data)
    /// ```
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the data is corrupted or if a required
    ///   property cannot be decoded.
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decode(String.self, forKey: .value)
        self.successUrl = try container.decode(String.self, forKey: .successUrl)
        self.realm = try container.decode(String.self, forKey: .realm)
    }

    /// Encodes this SSO token into the given encoder.
    ///
    /// This method is used automatically when encoding SSO tokens for storage
    /// (e.g., to Keychain, UserDefaults, or other persistence layers).
    /// You typically don't call this directly; instead, use standard encoding:
    ///
    /// ```swift
    /// let encoder = JSONEncoder()
    /// let data = try encoder.encode(token)
    /// ```
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if any values are invalid for the given
    ///   encoder's format.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(successUrl, forKey: .successUrl)
        try container.encode(realm, forKey: .realm)
    }
}
