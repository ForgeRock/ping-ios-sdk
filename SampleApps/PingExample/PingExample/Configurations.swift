//
//  Configurations.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Default configurations bundled with the app.
/// User-added configurations are persisted separately and merged at runtime.
///
/// The Journey entry below is a syntactically-valid placeholder so the sample compiles out of
/// the box; replace its values (or add your own entries here) with real tenant details before
/// running the flows. Alternatively, create configurations at runtime in the app's
/// Configurations screen — user-created entries are persisted and take precedence.
let defaultConfigurations: [Configuration] = [

    // MARK: - Journey Configurations
    //  TODO: Add Configurations with type `.journey` here. These will be used for the Journey sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, discovery endpoint, and environment based on your server configuration.
    Configuration(
        name: "My Journey Config", // for displaying in the list
        type: .journey,
        clientId: "replaceWithClientId",
        scopes: ["openid", "profile"], // Alter the scopes based on your clients configuration
        redirectUri: "com.example.davinci://callback",
        discoveryEndpoint: "https://example.com/am/oauth2/realms/root/realms/alpha/.well-known/openid-configuration",
        environment: "AIC", //"PingOne" or "AIC"
        cookieName: nil, // Optional, can be nil if not used
        serverUrl: nil, // Optional, can be nil if not used
        realm: "alpha" // Optional, can be nil if not used
    ),



    // MARK: - DaVinci Configurations
    //  TODO: Add Configurations with type `.davinci` here. These will be used for the DaVinci sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, signOut URI, discovery endpoint, and environment based on your server configuration.


    // MARK: - OIDC (Web) Configurations
    //  TODO: Add Configurations with type `.oidcWeb` here. These will be used for the OIDC sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, discovery endpoint, and environment based on your server configuration.


]
