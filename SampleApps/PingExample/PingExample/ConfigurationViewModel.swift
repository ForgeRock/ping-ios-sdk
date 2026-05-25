//
//  ConfigurationViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

//    The Configuration struct holds per-environment settings:
//        name, type (Journey/DaVinci/OIDC Web), clientId, scopes, redirectUri,
//        signOutUri, discoveryEndpoint, environment, cookieName, serverUrl, realm, acrValues.
//
//    The ConfigType enum defines the three authentication types with display names and icons.
//    Configurations are persisted as a diff overlay on top of defaultConfigurations in UserDefaults.

/// Holds all settings for a single SDK configuration entry.
struct Configuration: Codable, Sendable {
    var name: String
    var type: ConfigType
    var clientId: String
    var scopes: [String]
    var redirectUri: String
    var signOutUri: String?
    var discoveryEndpoint: String
    var deviceAuthorizationEndpoint: String?
    var environment: String
    var cookieName: String?
    var serverUrl: String?
    var realm: String?
    var acrValues: String?
    /// Enable PAR (Pushed Authorization Request) RFC 9126.
    var par: Bool?
    
    /// Whether this configuration is a bundled default (immutable in the UI).
    var isDefault: Bool {
        defaultConfigurations.contains(where: { $0.name == name })
    }
}

enum ConfigType: String, Codable, CaseIterable, Sendable {
    case journey = "Journey"
    case davinci = "DaVinci"
    case oidcWeb = "OIDC (Web)"
    case device = "Device Flow"

    var iconName: String {
        switch self {
        case .journey: return "map.fill"
        case .davinci: return "key.fill"
        case .oidcWeb: return "lock.shield.fill"
        case .device: return "tv"
        }
    }
}
