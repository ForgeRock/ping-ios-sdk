//
//  JsonConfig.swift
//  PingOidc
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Keys used in the unified SDK JSON configuration schema.
public enum JsonConfigKey {
    // MARK: - Top-level
    public static let oidc = "oidc"
    public static let journey = "journey"
    public static let log = "log"
    public static let timeout = "timeout"

    // MARK: - journey sub-dict
    public static let serverUrl = "serverUrl"
    public static let realm = "realm"
    public static let cookieName = "cookieName"

    // MARK: - oidc sub-dict — required
    public static let clientId = "clientId"
    public static let discoveryEndpoint = "discoveryEndpoint"
    public static let redirectUri = "redirectUri"
    public static let scopes = "scopes"

    // MARK: - oidc sub-dict — optional
    public static let signOutRedirectUri = "signOutRedirectUri"
    public static let refreshThreshold = "refreshThreshold"
    public static let par = "par"
    public static let loginHint = "loginHint"
    public static let state = "state"
    public static let nonce = "nonce"
    public static let display = "display"
    public static let prompt = "prompt"
    public static let uiLocales = "uiLocales"
    public static let acrValues = "acrValues"
    public static let additionalParameters = "additionalParameters"
    public static let openId = "openId"

    // MARK: - openId endpoint overrides
    public static let authorizationEndpoint = "authorizationEndpoint"
    public static let tokenEndpoint = "tokenEndpoint"
    public static let userinfoEndpoint = "userinfoEndpoint"
    public static let endSessionEndpoint = "endSessionEndpoint"
    public static let revocationEndpoint = "revocationEndpoint"
    public static let pushedAuthorizationRequestEndpoint = "pushedAuthorizationRequestEndpoint"
    public static let deviceAuthorizationEndpoint = "deviceAuthorizationEndpoint"
    public static let pingEndsessionEndpoint = "pingEndsessionEndpoint"
}

/// Errors thrown during JSON-based SDK configuration parsing.
public enum JsonConfigError: Error, LocalizedError, Sendable {
    /// A required field is absent from the JSON configuration.
    case missingRequiredField(String)
    /// A field is present but has an unexpected type.
    case invalidType(field: String, expected: String)

    public var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required configuration field: '\(field)'"
        case .invalidType(let field, let expected):
            return "Invalid type for configuration field '\(field)': expected \(expected)"
        }
    }
}

// MARK: - JSON parsing

/// Parses a unified SDK configuration dictionary.
///
/// Wraps a `[String: Any]` dictionary and provides typed accessors that throw
/// `JsonConfigError` on missing or incorrectly-typed fields.
public struct JsonConfigParser {
    private let json: [String: Any]

    public init(_ json: [String: Any]) {
        self.json = json
    }

    /// Returns the value for `key` cast to `T`. Throws `.missingRequiredField` when absent, `.invalidType` on wrong type.
    public func required<T>(_ key: String, field: String) throws -> T {
        guard let raw = json[key] else {
            throw JsonConfigError.missingRequiredField(field)
        }
        guard let value = raw as? T else {
            throw JsonConfigError.invalidType(field: field, expected: String(describing: T.self))
        }
        return value
    }

    /// Returns the value for `key` cast to `T`, or `defaultValue` when absent. Throws `.invalidType` on wrong type.
    public func optional<T>(_ key: String, field: String, default defaultValue: T) throws -> T {
        guard let raw = json[key] else { return defaultValue }
        guard let value = raw as? T else {
            throw JsonConfigError.invalidType(field: field, expected: String(describing: T.self))
        }
        return value
    }

    /// Returns the value for `key` cast to `T`, or `nil` when absent. Throws `.invalidType` on wrong type.
    public func optionalValue<T>(_ key: String, field: String) throws -> T? {
        guard let raw = json[key] else { return nil }
        guard let value = raw as? T else {
            throw JsonConfigError.invalidType(field: field, expected: String(describing: T.self))
        }
        return value
    }

    /// Parses `"log"` as a log-level string and returns the matching `Logger`. Defaults to `LogManager.logger` when absent.
    /// A present but wrong-type value is silently ignored (falls back to `LogManager.none`) rather than throwing,
    /// because log level is advisory and should never block SDK initialisation.
    public func logLevel() -> Logger {
        guard let raw = json[JsonConfigKey.log] else { return LogManager.logger }
        guard let level = raw as? String else { return LogManager.none }
        return LogManager.logger(forLevel: level)
    }

    /// Parses `"timeout"` as milliseconds and returns a `TimeInterval` in seconds. Defaults to `defaultValue` when absent.
    public func timeoutSeconds(default defaultValue: TimeInterval = 15.0) throws -> TimeInterval {
        guard let raw = json[JsonConfigKey.timeout] else { return defaultValue }
        guard let ms = raw as? Int else {
            throw JsonConfigError.invalidType(field: JsonConfigKey.timeout, expected: "int")
        }
        return Double(ms) / 1000.0
    }
}
