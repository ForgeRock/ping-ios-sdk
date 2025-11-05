
//
//  Constants.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Constants used throughout the PingBinding Module.
public struct Constants {
    
    // MARK: - Callback Input Keys
    
    /// The JWS (JSON Web Signature) key.
    public static let jws = "jws"
    /// The device ID key.
    public static let deviceId = "deviceId"
    /// The device name key.
    public static let deviceName = "deviceName"
    /// The client error key.
    public static let clientError = "clientError"
    
    // MARK: - Callback Output Keys
    
    /// The user ID key.
    public static let userId = "userId"
    /// The username key.
    public static let username = "username"
    /// The challenge key.
    public static let challenge = "challenge"
    /// The authentication type key.
    public static let authenticationType = "authenticationType"
    /// The title key.
    public static let title = "title"
    /// The subtitle key.
    public static let subtitle = "subtitle"
    /// The description key.
    public static let description = "description"
    /// The timeout key.
    public static let timeout = "timeout"
    /// The attestation key.
    public static let attestation = "attestation"
    
    // MARK: - JWT Constants
    
    /// The signature key.
    public static let sig: String = "sig"
    /// The algorithm key.
    public static let alg: String = "alg"
    /// The ES256 algorithm name.
    public static let ES256: String = "ES256"
    /// The JWS type.
    public static let JWS: String = "JWS"
    /// The subject key.
    public static let sub: String = "sub"
    /// The expiration time key.
    public static let exp: String = "exp"
    /// The issued at key.
    public static let iat: String = "iat"
    /// The not before key.
    public static let nbf: String = "nbf"
    /// The platform key.
    public static let platform: String = "platform"
    /// The iOS platform name.
    public static let ios: String = "ios"
    /// The issuer key.
    public static let iss: String = "iss"
    /// The DeviceBindingCallback key
    public static let deviceBindingCallback: String = "DeviceBindingCallback"
    /// The deviceSigningVerifierCallback key
    public static let deviceSigningVerifierCallback: String = "DeviceSigningVerifierCallback"
}
