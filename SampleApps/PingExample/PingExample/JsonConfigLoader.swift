//
//  JsonConfigLoader.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingOidc

enum JsonConfigLoader {
    /// Loads all bundled unified SDK configuration JSON files from the Configs/ folder in Bundle.main.
    /// Each file is emitted as its natural type (Journey or DaVinci) AND as an OIDC (Web) entry,
    /// since the unified JSON schema is compatible with all three SDK types.
    static func load() -> [Configuration] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Configs") else {
            return []
        }
        return urls.flatMap { parse(url: $0) }
    }

    private static func parse(url: URL) -> [Configuration] {
        let filename = url.lastPathComponent

        guard let data = try? Data(contentsOf: url) else {
            LogManager.logger.w("JsonConfigLoader: could not read '\(filename)'", error: nil)
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' is not valid JSON", error: nil)
            return []
        }
        guard let oidc = json[JsonConfigKey.oidc] as? [String: Any] else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' missing required 'oidc' object", error: nil)
            return []
        }
        guard let clientId = oidc[JsonConfigKey.clientId] as? String else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' missing required 'oidc.clientId'", error: nil)
            return []
        }
        guard let discoveryEndpoint = oidc[JsonConfigKey.discoveryEndpoint] as? String else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' missing required 'oidc.discoveryEndpoint'", error: nil)
            return []
        }
        guard let rawScopes = oidc[JsonConfigKey.scopes] as? [String] else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' missing required 'oidc.scopes'", error: nil)
            return []
        }
        guard let redirectUri = oidc[JsonConfigKey.redirectUri] as? String else {
            LogManager.logger.w("JsonConfigLoader: '\(filename)' missing required 'oidc.redirectUri'", error: nil)
            return []
        }

        let name = nameFromFilename(filename)
        let naturalType: ConfigType = json[JsonConfigKey.serverUrl] != nil ? .journey : .davinci
        let serverUrl = json[JsonConfigKey.serverUrl] as? String
        let realm = json[JsonConfigKey.realm] as? String
        let cookieName = json[JsonConfigKey.cookieName] as? String
        let signOutUri = oidc[JsonConfigKey.signOutRedirectUri] as? String
        let acrValues = oidc[JsonConfigKey.acrValues] as? String
        let environment = deriveEnvironment(from: discoveryEndpoint)

        let base = Configuration(
            name: name,
            type: naturalType,
            clientId: clientId,
            scopes: rawScopes,
            redirectUri: redirectUri,
            signOutUri: signOutUri,
            discoveryEndpoint: discoveryEndpoint,
            environment: environment,
            cookieName: cookieName,
            serverUrl: serverUrl,
            realm: realm,
            acrValues: acrValues,
            jsonFileName: filename
        )

        var oidcWeb = base
        oidcWeb.type = .oidcWeb

        var device = base
        device.type = .device
        device.deviceAuthorizationEndpoint = (oidc[JsonConfigKey.openId] as? [String: Any])?[JsonConfigKey.deviceAuthorizationEndpoint] as? String

        return [base, oidcWeb, device]
    }

    private static func nameFromFilename(_ filename: String) -> String {
        URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }

    private static func deriveEnvironment(from discoveryEndpoint: String) -> String {
        let lower = discoveryEndpoint.lowercased()
        if lower.contains("forgeblocks") || lower.contains("openam") { return "AIC" }
        return "PingOne"
    }
}
