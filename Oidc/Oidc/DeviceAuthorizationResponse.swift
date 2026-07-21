//
//  DeviceAuthorizationResponse.swift
//  PingOidc
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// Represents the server response to a device authorization request (RFC 8628).
public struct DeviceAuthorizationResponse: Decodable, Sendable {
    /// The device verification code.
    public let deviceCode: String
    /// The end-user verification code.
    public let userCode: String
    /// The end-user verification URI on the authorization server.
    public let verificationUri: String
    /// An optional verification URI that includes the `user_code` for non-textual transmission.
    public let verificationUriComplete: String?
    /// The lifetime in seconds of the `deviceCode` and `userCode`.
    public let expiresIn: Int
    /// The minimum amount of time in seconds the client should wait between polling requests.
    /// Defaults to `5` if absent from the server response.
    public let interval: Int

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
    }

    /// Decodes a `DeviceAuthorizationResponse` from the standard RFC 8628 JSON
    /// representation, mapping snake-case JSON keys to camelCase properties.
    /// `interval` defaults to `5` seconds when omitted by the server.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceCode = try container.decode(String.self, forKey: .deviceCode)
        userCode = try container.decode(String.self, forKey: .userCode)
        verificationUri = try container.decode(String.self, forKey: .verificationUri)
        verificationUriComplete = try container.decodeIfPresent(String.self, forKey: .verificationUriComplete)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 5
    }
}
