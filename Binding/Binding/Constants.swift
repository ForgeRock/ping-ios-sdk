
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

/// Constants used throughout the PingBinding SDK.
struct Constants {
    
    // MARK: - Callback Input Keys
    
    static let jws = "jws"
    static let deviceId = "deviceId"
    static let deviceName = "deviceName"
    static let clientError = "clientError"
    
    // MARK: - Callback Output Keys
    
    static let userId = "userId"
    static let username = "username"
    static let challenge = "challenge"
    static let authenticationType = "authenticationType"
    static let title = "title"
    static let subtitle = "subtitle"
    static let description = "description"
    static let timeout = "timeout"
    static let attestation = "attestation"
    
    // MARK: - JWT Constants
    
    static let sig: String = "sig"
    static let alg: String = "alg"
    static let ES256: String = "ES256"
    static let JWS: String = "JWS"
    static let sub: String = "sub"
    static let exp: String = "exp"
    static let iat: String = "iat"
    static let nbf: String = "nbf"
    static let platform: String = "platform"
    static let ios: String = "ios"
    static let iss: String = "iss"
}
