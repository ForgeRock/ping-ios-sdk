//
//  Constants.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// Represents various constants used in Journey requests and flows.
public enum JourneyConstants {
    
    public static let realm = "root"
    public static let cookie = "iPlanetDirectoryPro"

    public static let startRequest = "com.pingidentity.journey.START_REQUEST"
    public static let forceAuth = "com.pingidentity.journey.FORCE_AUTH"
    public static let noSession = "com.pingidentity.journey.NO_SESSION"
    public static let authIndexType = "authIndexType"
    public static let authIndexValue = "authIndexValue"
    public static let service = "service"
    public static let suspendedId = "suspendedId"

    public static let forceAuthParam = "ForceAuth"
    public static let noSessionParam = "noSession"

    public static let sessionConfig = "com.pingidentity.journey.SESSION_CONFIG"
    public static let resource31 = "resource=3.1, protocol=1.0"

    public static let acceptApiVersion = "Accept-API-Version"
    public static let resource21Protocol10 = "resource=2.1, protocol=1.0"

    public static let authId = "authId"
    public static let callbacks = "callbacks"
    public static let contentType = "Content-Type"
    public static let applicationJson = "application/json"
    public static let tokenId = "tokenId"
    public static let successUrl = "successUrl"
    public static let realmName = "realm"
    
    public static let location = "location"
    public static let type = "type"
    
    /// Constant key used to store and retrieve the OIDC client from the shared context
    public static let oidcClient = "com.pingidentity.journey.OIDC_CLIENT"
    
    /// Callback Types
    public static let nameCallback = "NameCallback"
    public static let passwordCallback = "PasswordCallback"
    
    // Response keys
    public static let message = "message"
    
    // OIDC Requests
    public static let client_id = "client_id"
    public static let scope = "scope"
    public static let state = "state"
    public static let grant_type = "grant_type"
    public static let refresh_token = "refresh_token"
    public static let token = "token"
    public static let authorization_code = "authorization_code"
    public static let redirect_uri = "redirect_uri"
    public static let code_verifier = "code_verifier"
    public static let code = "code"
    public static let id_token_hint = "id_token_hint"
    public static let response_type = "response_type"
    public static let code_challenge = "code_challenge"
    public static let code_challenge_method = "code_challenge_method"
    public static let nonce = "nonce"
    public static let login_hint = "login_hint"
    public static let prompt = "prompt"
}
