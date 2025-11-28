//
//  NetworkConstants.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// Shared network string constants used across the module.
public enum NetworkConstants {
    // Standard headers
    public static let headerRequestedWith = "x-requested-with"
    public static let headerRequestedPlatform = "x-requested-platform"
    public static let headerContentType = "Content-Type"
    public static let headerCookie = "Cookie"
    public static let headerSetCookie = "Set-Cookie"
    public static let headerSetCookieLowercased = "set-cookie"
    public static let headerAuthorization = "Authorization"
    public static let headerAcceptLanguage = "Accept-Language"
    
    // Standard header values
    public static let requestedWithValue = "ping-sdk"
    public static let requestedPlatformValue = "ios"
    public static let bearerValue = "Bearer"

    // Content types
    public static let contentTypeJSON = "application/json"
    public static let contentTypeForm = "application/x-www-form-urlencoded"

    // Common cookie names
    public static let stCookie = "ST"
    public static let stNoSsCookie = "ST-NO-SS"

    // Common request parameters and keys
    public static let _links = "_links"
    public static let `continue`  = "continue"
    public static let href = "href"
    public static let idToken = "idToken"
    public static let accessToken = "accessToken"
}