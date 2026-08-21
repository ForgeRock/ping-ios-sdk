//
//  OidcClientConfig.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingNetwork
import PingLogger
import PingStorage

/// Configuration class for OIDC client.
///
/// - Important: This class is `@unchecked Sendable` and contains mutable `var` fields.
///   Configure all properties before passing the instance to any client or workflow — do
///   not mutate it afterwards, as it may be read concurrently from background threads.
public class OidcClientConfig: @unchecked Sendable {
    nonisolated(unsafe) private static let endpointSetters: [(String, (inout OpenIdConfiguration, String) -> Void)] = [
        (JsonConfigKey.authorizationEndpoint,              { $0.authorizationEndpoint = $1 }),
        (JsonConfigKey.tokenEndpoint,                      { $0.tokenEndpoint = $1 }),
        (JsonConfigKey.userinfoEndpoint,                   { $0.userinfoEndpoint = $1 }),
        (JsonConfigKey.endSessionEndpoint,                 { $0.endSessionEndpoint = $1 }),
        (JsonConfigKey.revocationEndpoint,                 { $0.revocationEndpoint = $1 }),
        (JsonConfigKey.pushedAuthorizationRequestEndpoint, { $0.pushedAuthorizationRequestEndpoint = $1 }),
        (JsonConfigKey.deviceAuthorizationEndpoint,        { $0.deviceAuthorizationEndpoint = $1 }),
        (JsonConfigKey.pingEndsessionEndpoint,             { $0.pingEndsessionEndpoint = $1 }),
    ]

    /// OpenID configuration.
    ///
    /// Set this to configure the SDK from explicit endpoints and skip OpenID discovery entirely;
    /// leave `nil` to discover from `discoveryEndpoint`. Must be set before the config is handed
    /// to a client or workflow (see the class-level `@unchecked Sendable` note).
    public var openId: OpenIdConfiguration?
    /// Token refresh threshold in seconds.
    public var refreshThreshold: Int64 = 0
    /// Agent delegate for handling OIDC operations.
    internal var agent: (any AgentDelegateProtocol)?
    /// Logger instance for logging.
    public var logger: Logger = LogManager.logger
    /// Storage delegate for storing tokens.
    public var storage: StorageDelegate<Token>
    /// Discovery endpoint URL.
    public var discoveryEndpoint = ""
    /// Client ID for OIDC.
    public var clientId = ""
    /// Set of scopes for OIDC.
    public var scopes = Set<String>()
    /// Redirect URI for OIDC.
    public var redirectUri = ""
    /// Login hint for OIDC.
    public var loginHint: String?
    /// State parameter for OIDC.
    public var state: String?
    /// Nonce parameter for OIDC.
    public var nonce: String?
    /// Display parameter for OIDC.
    public var display: String?
    /// Prompt parameter for OIDC.
    public var prompt: String?
    /// UI locales parameter for OIDC.
    public var uiLocales: String?
    /// ACR values parameter for OIDC.
    public var acrValues: String?
    /// Additional parameters for OIDC.
    public var additionalParameters = [String: String]()
    /// Enable PAR (Pushed Authorization Request) RFC 9126.
    /// When enabled, authorization parameters are pushed to the server before authorization.
    public var par: Bool = false
    /// HTTP client for making network requests.
    public var httpClient: (any HttpClientProtocol)?
    /// Called once, after OpenID discovery completes or against a pre-supplied `openId`,
    /// allowing callers to patch any field on the `OpenIdConfiguration` before it is used
    /// (e.g. override `deviceAuthorizationEndpoint` for a non-standard server).
    public var openIdOverride: ((inout OpenIdConfiguration) -> Void)?
    /// Tracks whether `openIdOverride` has already been applied, so that re-entrant
    /// `oidcInitialize()` calls never run a caller-supplied closure more than once.
    private var openIdOverrideApplied = false

    /// Initializes a new `OidcClientConfig` instance.
    public init() {
        storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE", encryptor: SecuredKeyEncryptor() ?? NoEncryptor(), cacheStrategy: .NO_CACHE)
    }
    
    ///  Adds a scope to the set of scopes.
    /// - Parameter scope: The scope to add.
    public func scope(_ scope: String) {
        scopes.insert(scope)
    }
    
    /// Updates the agent with the provided configuration.
    /// - Parameters:
    ///   - agent: The agent to update.
    ///   - config: The configuration block for the agent.
    public func updateAgent<T: Any>(_ agent: any Agent<T>, config: (T) -> Void = {_ in }) {
        self.agent = AgentDelegate<T>(agent: agent, agentConfig: agent.config()(), oidcClientConfig: self)
    }
    
    /// Initializes the lazy properties to their default values.
    ///
    /// Discovery is performed only when `openId` has not been supplied by the caller, so a
    /// pre-configured `OpenIdConfiguration` skips the network round-trip entirely. Whichever
    /// document ends up in `openId` — discovered or pre-supplied — is patched by
    /// `openIdOverride` exactly once, even though every `OidcClient` entry point re-enters
    /// this method.
    public func oidcInitialize() async throws {
        if httpClient == nil {
            httpClient = HttpClient.createClient()
        }

        if openId == nil {
            openId = try await discover()
        }

        if var configuration = openId, !openIdOverrideApplied {
            openIdOverride?(&configuration)
            openId = configuration
            openIdOverrideApplied = true
        }
    }
    
    /// Discovers the OpenID configuration from the discovery endpoint.
    /// - Returns: The discovered OpenID configuration.
    private func discover() async throws -> OpenIdConfiguration? {
        guard URL(string: discoveryEndpoint) != nil else {
            logger.e("Invalid Discovery URL", error: nil)
            return nil
        }
        
        guard let httpClient else {
            logger.e("Invalid Http Client URL", error: nil)
            return nil
        }
        
        let response = try await httpClient.request { request in
            request.url = self.discoveryEndpoint
        }
        guard response.status.isSuccess() else {
            throw OidcError.apiError(code: response.status, message: response.bodyAsString())
        }
        let configuration = try JSONDecoder().decode(OpenIdConfiguration.self, from: response.body ?? Data())
        return configuration
    }
    
    /// Creates an `OidcClientConfig` from an `oidc` sub-dictionary and a pre-resolved logger.
    /// Used by all `createXxx(json:)` factories to avoid repeating the same construction sequence.
    public static func from(oidcJson: [String: Any], logger: Logger) throws -> OidcClientConfig {
        let config = OidcClientConfig()
        config.logger = logger
        try config.apply(json: oidcJson)
        return config
    }

    /// Clones the current configuration.
    /// - Returns: A new instance of OidcClientConfig with the same properties.
    public func clone() -> OidcClientConfig {
        let cloned = OidcClientConfig()
        cloned.update(with: self)
        return cloned
    }
    
    /// Merges another configuration into this one.
    ///
    /// - Important: This method is intended for **module wiring only** — it is called by the
    ///   `createXxx(json:)` and `createXxx(block:)` factories to propagate a parsed config into
    ///   a workflow module. Do **not** call this on an `OidcClientConfig` that has already been
    ///   passed to a running workflow or client: it replaces every field including `storage` and
    ///   `openId`, which can cause in-flight token reads to hit an unexpected (empty) keychain slot.
    ///
    /// The "`openIdOverride` already applied" flag is carried over as well, so a clone of an
    /// already-initialised configuration does not re-run the override closure on a document that
    /// has already been patched.
    /// - Parameter other: The other configuration to merge.
    public func update(with other: OidcClientConfig) {
        self.openId = other.openId
        self.refreshThreshold = other.refreshThreshold
        self.agent = other.agent
        self.logger = other.logger
        self.storage = other.storage
        self.discoveryEndpoint = other.discoveryEndpoint
        self.clientId = other.clientId
        self.scopes = other.scopes
        self.redirectUri = other.redirectUri
        self.loginHint = other.loginHint
        self.state = other.state
        self.nonce = other.nonce
        self.display = other.display
        self.prompt = other.prompt
        self.uiLocales = other.uiLocales
        self.acrValues = other.acrValues
        self.additionalParameters = other.additionalParameters
        self.par = other.par
        self.httpClient = other.httpClient
        self.openIdOverride = other.openIdOverride
        self.openIdOverrideApplied = other.openIdOverrideApplied
    }
    
    /// Applies a unified JSON configuration dictionary to this instance.
    ///
    /// Validates all required fields and writes every recognised field directly to `self`.
    /// Unknown fields (including `signOutRedirectUri`) are silently ignored for forward compatibility.
    ///
    /// `discoveryEndpoint` is required unless an `openId` sub-object is supplied. When `openId` is
    /// supplied without `discoveryEndpoint` it replaces the discovery document (no network call) and
    /// `tokenEndpoint` becomes required. When both are supplied, discovery runs and `openId` patches
    /// the discovered document. A blank `discoveryEndpoint` counts as absent, since discovery can
    /// never succeed against it.
    ///
    /// - Important: If the JSON contains an `openId` sub-object, this method **merges** the
    ///   JSON-derived endpoint overrides with any existing `openIdOverride`. The existing closure
    ///   runs first, then the JSON-derived overrides are applied on top, so the JSON values win
    ///   for any endpoint key they cover. If the JSON contains no `openId` key, `openIdOverride`
    ///   is left unchanged.
    ///
    /// - Parameter json: The `oidc` sub-dictionary from the unified SDK configuration schema.
    /// - Throws: `JsonConfigError` if a required field is absent or a field has the wrong type.
    public func apply(json: [String: Any]) throws {
        let p = JsonConfigParser(json)
        let f: (String) -> String = { "\(JsonConfigKey.oidc).\($0)" }
        let fOpenId: (String) -> String = { "\(JsonConfigKey.oidc).\(JsonConfigKey.openId).\($0)" }

        // --- Required fields ---
        let clientId: String          = try p.required(JsonConfigKey.clientId,          field: f(JsonConfigKey.clientId))
        let redirectUri: String       = try p.required(JsonConfigKey.redirectUri,       field: f(JsonConfigKey.redirectUri))

        // --- discoveryEndpoint / openId (conditionally required) ---
        // A blank `discoveryEndpoint` is treated as absent: discovery can never succeed against it,
        // and bridges that always emit the key would otherwise be locked out of the no-discovery path.
        let rawDiscoveryEndpoint: String? = try p.optionalValue(JsonConfigKey.discoveryEndpoint, field: f(JsonConfigKey.discoveryEndpoint))
        let discoveryEndpoint = OidcClientConfig.nonBlank(rawDiscoveryEndpoint)
        let openIdDict: [String: Any]? = try p.optionalValue(JsonConfigKey.openId, field: f(JsonConfigKey.openId))

        if discoveryEndpoint == nil && openIdDict == nil {
            throw JsonConfigError.missingRequiredField(f(JsonConfigKey.discoveryEndpoint))
        }

        let rawScopes: [Any] = try p.required(JsonConfigKey.scopes, field: f(JsonConfigKey.scopes))
        var parsedScopes = Set<String>()
        for element in rawScopes {
            guard let scope = element as? String else {
                throw JsonConfigError.invalidType(field: f(JsonConfigKey.scopes), expected: "array of strings")
            }
            parsedScopes.insert(scope)
        }

        // --- Optional fields ---
        let refreshThresholdInt: Int = try p.optional(JsonConfigKey.refreshThreshold, field: f(JsonConfigKey.refreshThreshold), default: 0)
        let parsedPar: Bool          = try p.optional(JsonConfigKey.par,              field: f(JsonConfigKey.par),              default: false)

        let loginHint:  String? = try p.optionalValue(JsonConfigKey.loginHint,  field: f(JsonConfigKey.loginHint))
        let state:      String? = try p.optionalValue(JsonConfigKey.state,      field: f(JsonConfigKey.state))
        let nonce:      String? = try p.optionalValue(JsonConfigKey.nonce,      field: f(JsonConfigKey.nonce))
        let display:    String? = try p.optionalValue(JsonConfigKey.display,    field: f(JsonConfigKey.display))
        let prompt:     String? = try p.optionalValue(JsonConfigKey.prompt,     field: f(JsonConfigKey.prompt))
        let uiLocales:  String? = try p.optionalValue(JsonConfigKey.uiLocales,  field: f(JsonConfigKey.uiLocales))
        let acrValues:  String? = try p.optionalValue(JsonConfigKey.acrValues,  field: f(JsonConfigKey.acrValues))

        // --- additionalParameters ---
        var parsedAdditional = [String: String]()
        if let rawDict: [String: Any] = try p.optionalValue(JsonConfigKey.additionalParameters, field: f(JsonConfigKey.additionalParameters)) {
            for (key, value) in rawDict {
                guard let stringValue = value as? String else {
                    throw JsonConfigError.invalidType(field: f("\(JsonConfigKey.additionalParameters).\(key)"), expected: "string")
                }
                parsedAdditional[key] = stringValue
            }
        }

        // --- openId endpoint overrides (optional) ---
        // Maps to `openIdOverride` — applied to the OpenID document exactly once (see oidcInitialize).
        // To add a new endpoint: add one entry to `endpointSetters`; no other change required.
        var parsedOpenIdOverrides = [String: String]()
        if let openIdDict {
            for (key, _) in OidcClientConfig.endpointSetters {
                if let raw = openIdDict[key] {
                    guard let value = raw as? String else {
                        throw JsonConfigError.invalidType(field: fOpenId(key), expected: "string")
                    }
                    parsedOpenIdOverrides[key] = value
                }
            }
        }

        // --- openId as a replacement for the discovery document ---
        // No `discoveryEndpoint` means the `openId` sub-object *is* the document, so `tokenEndpoint`
        // becomes required; every other non-optional endpoint defaults to "" and the optional ones
        // to nil, matching the leniency the rest of the SDK already applies to those fields.
        var seededOpenId: OpenIdConfiguration?
        if discoveryEndpoint == nil, openIdDict != nil {
            guard OidcClientConfig.nonBlank(parsedOpenIdOverrides[JsonConfigKey.tokenEndpoint]) != nil else {
                throw JsonConfigError.missingRequiredField(fOpenId(JsonConfigKey.tokenEndpoint))
            }
            var openId = OpenIdConfiguration(
                authorizationEndpoint: "",
                tokenEndpoint: "",
                userinfoEndpoint: "",
                endSessionEndpoint: "",
                revocationEndpoint: ""
            )
            for (key, setter) in OidcClientConfig.endpointSetters {
                if let value = parsedOpenIdOverrides[key] { setter(&openId, value) }
            }
            seededOpenId = openId
        }

        // All validation passed — apply to self
        self.clientId = clientId
        self.discoveryEndpoint = discoveryEndpoint ?? ""
        self.scopes = parsedScopes
        self.redirectUri = redirectUri
        self.refreshThreshold = Int64(refreshThresholdInt)
        self.par = parsedPar
        self.loginHint = loginHint
        self.state = state
        self.nonce = nonce
        self.display = display
        self.prompt = prompt
        self.uiLocales = uiLocales
        self.acrValues = acrValues
        self.additionalParameters = parsedAdditional

        // Only set when the `openId` sub-object stands in for the discovery document; a pre-supplied
        // `openId` (or the document discovery is about to fetch) is left untouched otherwise.
        if let seededOpenId {
            self.openId = seededOpenId
        }

        // Installed in both branches: against a seeded document the overrides are a no-op, which keeps
        // a single override-installation code path.
        if !parsedOpenIdOverrides.isEmpty {
            let overrides = parsedOpenIdOverrides
            let existing = self.openIdOverride
            self.openIdOverride = { openId in
                existing?(&openId)
                for (key, setter) in OidcClientConfig.endpointSetters {
                    if let v = overrides[key] { setter(&openId, v) }
                }
            }
        }
    }

    // MARK: - Private

    /// Returns `value` when it holds at least one non-whitespace character, otherwise `nil`.
    /// Used by `apply(json:)` to treat blank endpoint strings as absent.
    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
