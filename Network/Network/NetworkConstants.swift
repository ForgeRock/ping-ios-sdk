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
///
/// These constants provide standardized header names, content types, and common
/// parameter keys used throughout the Ping SDK network layer.
public enum NetworkConstants {
    // MARK: - Standard Headers
    
    /// Header name for SDK identification: "x-requested-with"
    public static let headerRequestedWith = "x-requested-with"
    
    /// Header name for platform identification: "x-requested-platform"
    public static let headerRequestedPlatform = "x-requested-platform"
    
    /// Header name for content type: "Content-Type"
    public static let headerContentType = "Content-Type"
    
    /// Header name for cookies: "Cookie"
    public static let headerCookie = "Cookie"
    
    /// Header name for setting cookies: "Set-Cookie"
    public static let headerSetCookie = "Set-Cookie"
    
    /// Lowercase version of Set-Cookie header for case-insensitive lookups: "set-cookie"
    public static let headerSetCookieLowercased = "set-cookie"
    
    /// Header name for authorization: "Authorization"
    public static let headerAuthorization = "Authorization"
    
    /// Header name for accept language: "Accept-Language"
    public static let headerAcceptLanguage = "Accept-Language"
    
    // MARK: - Standard Header Values
    
    /// Default value for x-requested-with header: "ping-sdk"
    public static let requestedWithValue = "ping-sdk"
    
    /// Default value for x-requested-platform header: "ios"
    public static let requestedPlatformValue = "ios"
    
    /// Bearer token prefix: "Bearer"
    public static let bearerValue = "Bearer"

    // MARK: - Content Types
    
    /// JSON content type: "application/json"
    public static let contentTypeJSON = "application/json"
    
    /// Form URL-encoded content type: "application/x-www-form-urlencoded"
    public static let contentTypeForm = "application/x-www-form-urlencoded"

    // MARK: - Common Cookie Names
    
    /// Session token cookie name: "ST"
    public static let stCookie = "ST"
    
    /// Session token without single sign-on cookie name: "ST-NO-SS"
    public static let stNoSsCookie = "ST-NO-SS"

    // MARK: - Common Request Parameters and Keys
    
    /// HATEOAS links key: "_links"
    public static let _links = "_links"
    
    /// Continue flow parameter key: "continue"
    public static let `continue`  = "continue"
    
    /// HREF link key: "href"
    public static let href = "href"
    
    /// ID token key: "idToken"
    public static let idToken = "idToken"
    
    /// Access token key: "accessToken"
    public static let accessToken = "accessToken"
}