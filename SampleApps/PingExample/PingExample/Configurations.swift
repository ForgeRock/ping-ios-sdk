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
let defaultConfigurations: [Configuration] = [
    
    // MARK: - Journey Configurations
    //  TODO: Add Configurations with type `.journey` here. These will be used for the Journey sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, discovery endpoint, and environment based on your server configuration.
    Configuration(
        name: <#"Configuration name"#>, // for displaying in the list
        type: .journey,
        clientId: <#"Client ID"#>,
        scopes: [<#"scope1"#>, <#"scope2"#>, <#"scope3"#>], // Alter the scopes based on your clients configuration
        redirectUri: <#"Redirect URI"#>,
        discoveryEndpoint: <#"Discovery Endpoint"#>,
        environment: "AIC", //"PingOne" or "AIC"
        cookieName:  <#"Cookie Name"#>, // Optional, can be nil if not used
        serverUrl: <#"Server URL"#>, // Optional, can be nil if not used
        realm: <#"Realm"#> // Optional, can be nil if not used
    ),
    
    
    
    // MARK: - DaVinci Configurations
    //  TODO: Add Configurations with type `.davinci` here. These will be used for the DaVinci sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, signOut URI, discovery endpoint, and environment based on your server configuration.
    
    
    // MARK: - OIDC (Web) Configurations
    //  TODO: Add Configurations with type `.oidcWeb` here. These will be used for the OIDC sample flows. Ensure to fill in the required details such as client ID, scopes, redirect URI, discovery endpoint, and environment based on your server configuration.
    
    
]
