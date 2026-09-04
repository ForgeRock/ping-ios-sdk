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

/// Coalesces concurrent `oidcInitialize()` calls on the same `OidcClientConfig` instance so
/// simultaneous first-use callers share one in-flight initialization instead of independently
/// racing through discovery and `openIdOverride` application.
///
/// - Important: Awaiting the shared task does not respond to the awaiting task being cancelled —
///   a cancelled caller rides out the shared discovery to completion instead of tearing it down
///   for everyone else. This is a deliberate trade-off: it keeps the coordinator free of custom
///   cancellation machinery and lets cancellation propagate only where the shared work itself
///   observes it. A caller that needs to abandon an initialization should structure its calling
///   code (e.g. task wrapping) so it can move on while initialization continues.
private actor OidcInitializationCoordinator {
    private var inFlightTask: Task<Void, any Error>?

    /// Runs `operation` at most once concurrently: a caller that finds no task in flight starts
    /// one and awaits it; a caller that finds one already running awaits that same task instead
    /// of starting a second discovery/override cycle.
    ///
    /// The in-flight task clears itself as its very last step (via `defer`), so a caller retrying
    /// immediately after a failure always starts a genuinely fresh attempt instead of ever
    /// rejoining a task that has already finished. Failures are never cached.
    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        let task: Task<Void, any Error> = currentOrNewTask(operation)
        try await task.value
    }

    private func currentOrNewTask(_ operation: @escaping @Sendable () async throws -> Void) -> Task<Void, any Error> {
        if let inFlightTask {
            return inFlightTask
        }
        let task = Task {
            defer { self.clearInFlightTask() }
            try await operation()
        }
        inFlightTask = task
        return task
    }

    private func clearInFlightTask() {
        inFlightTask = nil
    }
}

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
    /// - Important: Setting this directly before calling `oidcInitialize()` (or before the
    ///   config is handed to a `createXxx` factory) skips network discovery entirely — see the
    ///   "configure before use" contract documented on this class.
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
    /// Caller-supplied override, set directly via the public `openIdOverride` property below.
    private var programmaticOpenIdOverride: ((inout OpenIdConfiguration) -> Void)?
    /// Override synthesized from the most recently applied JSON `openId` sub-object. Replaced
    /// wholesale by `apply(json:)` whenever its JSON supplies an `openId` sub-object (never
    /// nested under a prior JSON layer); left untouched when a JSON configuration omits `openId`.
    private var jsonOpenIdOverride: ((inout OpenIdConfiguration) -> Void)?

    /// Called once after OpenID discovery completes, allowing callers to patch any field
    /// on the discovered `OpenIdConfiguration` before it is used (e.g. override
    /// `deviceAuthorizationEndpoint` for a non-standard server).
    ///
    /// Reading this property returns the programmatic override composed with any JSON-derived
    /// endpoint overrides installed by `apply(json:)`, with the JSON values applied second so
    /// they win for any endpoint key they cover. Assigning to it sets only the programmatic
    /// layer — the JSON-derived layer is managed separately by `apply(json:)` and is replaced
    /// wholesale (never nested) on each call that supplies an `openId` sub-object, so
    /// reconfiguring via JSON never leaks a stale override for a key the new configuration no
    /// longer specifies.
    public var openIdOverride: ((inout OpenIdConfiguration) -> Void)? {
        get {
            let programmatic = programmaticOpenIdOverride
            let json = jsonOpenIdOverride
            guard programmatic != nil || json != nil else { return nil }
            return { configuration in
                programmatic?(&configuration)
                json?(&configuration)
            }
        }
        set { programmaticOpenIdOverride = newValue }
    }

    /// Tracks whether the effective `openIdOverride` has already been applied to the currently
    /// materialized `openId` document, so that re-entrant `oidcInitialize()` calls never run it
    /// more than once against the same document. Reset by `apply(json:)` on every successful
    /// call, since a newly committed configuration is a new OpenID source even when a document
    /// happens to already be materialized.
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
    
    /// Coordinates concurrent `oidcInitialize()` calls on this instance; see
    /// `OidcInitializationCoordinator`.
    private let initializationCoordinator = OidcInitializationCoordinator()

    /// Initializes the lazy properties to their default values.
    ///
    /// Discovery is performed only when `openId` has not been supplied by the caller, so a
    /// pre-configured `OpenIdConfiguration` skips the network round-trip entirely.
    ///
    /// Concurrent calls on the same instance are coordinated: a caller that arrives while another
    /// is already discovering/applying the override awaits that same in-flight operation instead
    /// of issuing a second discovery request or reapplying the override a second time. Awaiting
    /// the shared operation does not respond to cancellation of the calling task — see
    /// `OidcInitializationCoordinator`.
    ///
    /// - Throws: `OidcError.configurationError` when neither `openId` nor a usable
    ///   `discoveryEndpoint` is configured, or any error surfaced by discovery itself
    ///   (`OidcError.apiError`, a decoding failure, a transport error). A failure leaves `openId`
    ///   `nil`, so a subsequent call retries fresh.
    public func oidcInitialize() async throws {
        try await initializationCoordinator.run {
            try await self.performOidcInitialization()
        }
    }

    /// The actual discover-then-override sequence, run at most once concurrently per instance
    /// via `initializationCoordinator`. Single-flight via `initializationCoordinator` — see
    /// `oidcInitialize()`.
    private func performOidcInitialization() async throws {
        if httpClient == nil {
            httpClient = HttpClient.createClient()
        }

        if openId == nil {
            // A failed discovery throws, which leaves `openId` nil so a later call can retry.
            openId = try await discover()
        }

        if var discovered = openId, !openIdOverrideApplied {
            openIdOverride?(&discovered)
            openId = discovered
            openIdOverrideApplied = true
        }
    }
    
    /// Discovers the OpenID configuration from the discovery endpoint.
    /// - Returns: The discovered OpenID configuration.
    /// - Throws: `OidcError.configurationError` when `discoveryEndpoint` is blank or malformed,
    ///   or no HTTP client is available; `OidcError.apiError` when the endpoint responds with a
    ///   non-success status.
    private func discover() async throws -> OpenIdConfiguration {
        guard URL(string: discoveryEndpoint) != nil else {
            let message = "No OpenID configuration: set either `openId` directly, or a valid `discoveryEndpoint` — got \"\(discoveryEndpoint)\"."
            logger.e(message, error: nil)
            throw OidcError.configurationError(message: message)
        }

        guard let httpClient else {
            let message = "No HTTP client available to fetch the OpenID configuration from \(discoveryEndpoint)."
            logger.e(message, error: nil)
            throw OidcError.configurationError(message: message)
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
        self.programmaticOpenIdOverride = other.programmaticOpenIdOverride
        self.jsonOpenIdOverride = other.jsonOpenIdOverride
        self.openIdOverrideApplied = other.openIdOverrideApplied
    }
    
    /// Applies a unified JSON configuration dictionary to this instance.
    ///
    /// Validates all required fields and writes every recognised field directly to `self`.
    /// Unknown fields (including `signOutRedirectUri`) are silently ignored for forward compatibility.
    ///
    /// `discoveryEndpoint` and `openId` jointly determine how (or whether) OpenID discovery runs,
    /// with three possible outcomes:
    /// - **`discoveryEndpoint` present:** unchanged from prior behavior. Discovery runs normally.
    ///   If an `openId` sub-object is also present, it is parsed as **partial endpoint overrides**
    ///   and installed as the JSON-derived layer of `openIdOverride`, applied on top of any
    ///   programmatic override (set directly via the public `openIdOverride` property) so the
    ///   JSON values win for any endpoint key they cover. Those overrides are applied to the
    ///   *discovered* configuration after `discover()` succeeds (see `oidcInitialize()`). If
    ///   `openId` is absent from this call, the JSON-derived layer is left unchanged.
    /// - **`discoveryEndpoint` absent, `openId` present:** the `openId` sub-object *is* the OpenID
    ///   configuration — it is parsed and assigned directly to `self.openId` and no network
    ///   request is made. `oidc.openId.tokenEndpoint` becomes required; every other non-optional
    ///   endpoint defaults to `""` and the optional ones to `nil`, matching the leniency the rest
    ///   of the SDK already applies to those fields — so supply every endpoint your flow actually
    ///   uses. `self.discoveryEndpoint` remains `""` and `oidcInitialize()` skips discovery, since
    ///   it short-circuits whenever `openId != nil`.
    /// - **Both absent:** throws `JsonConfigError.missingRequiredField` for `discoveryEndpoint`.
    ///
    /// - Important: A successful call reconfigures the OpenID source and invalidates whatever was
    ///   materialized before, even if this instance was already initialized: the replacement path
    ///   seeds the new document directly; the discovery path clears `self.openId` so the next
    ///   `oidcInitialize()` rediscovers rather than reapplying a new override to a stale,
    ///   previously-discovered document. The JSON-derived override layer is replaced wholesale on
    ///   each call that supplies an `openId` sub-object (never nested under a prior JSON layer),
    ///   including the replacement case, so a key the new configuration no longer specifies never
    ///   leaks a stale override value from an earlier call.
    ///
    /// - Parameter json: The `oidc` sub-dictionary from the unified SDK configuration schema.
    /// - Throws: `JsonConfigError` if a required field is absent or a field has the wrong type.
    public func apply(json: [String: Any]) throws {
        let p = JsonConfigParser(json)
        let f: (String) -> String = { "\(JsonConfigKey.oidc).\($0)" }
        let fOpenId: (String) -> String = { "\(JsonConfigKey.oidc).\(JsonConfigKey.openId).\($0)" }

        // --- Required fields ---
        let clientId: String    = try p.required(JsonConfigKey.clientId,    field: f(JsonConfigKey.clientId))
        let redirectUri: String = try p.required(JsonConfigKey.redirectUri, field: f(JsonConfigKey.redirectUri))

        let rawScopes: [Any] = try p.required(JsonConfigKey.scopes, field: f(JsonConfigKey.scopes))
        var parsedScopes = Set<String>()
        for element in rawScopes {
            guard let scope = element as? String else {
                throw JsonConfigError.invalidType(field: f(JsonConfigKey.scopes), expected: "array of strings")
            }
            parsedScopes.insert(scope)
        }

        // --- discoveryEndpoint / openId (mutually-completing; see doc comment above) ---
        // Read both, once, up front — the branch below decides whether `openId` is a set of
        // partial post-discovery overrides or a complete, discovery-skipping replacement.
        let discoveryEndpoint: String?  = try p.optionalValue(JsonConfigKey.discoveryEndpoint, field: f(JsonConfigKey.discoveryEndpoint))
        let openIdDict: [String: Any]?  = try p.optionalValue(JsonConfigKey.openId,             field: f(JsonConfigKey.openId))

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

        // --- openId: partial post-discovery overrides, or a lenient discovery-skipping replacement ---
        // Which of the two `openId` means is decided by whether `discoveryEndpoint` is present —
        // see the doc comment on `apply(json:)` for the full three-way rationale.
        var parsedOpenIdOverrides = [String: String]()
        var seededOpenId: OpenIdConfiguration?
        if let openIdDict {
            // To add a new endpoint: add one entry to `endpointSetters`; no other change required.
            for (key, _) in OidcClientConfig.endpointSetters {
                if let raw = openIdDict[key] {
                    guard let value = raw as? String else {
                        throw JsonConfigError.invalidType(field: fOpenId(key), expected: "string")
                    }
                    parsedOpenIdOverrides[key] = value
                }
            }
        }

        if discoveryEndpoint == nil {
            guard openIdDict != nil else {
                throw JsonConfigError.missingRequiredField(f(JsonConfigKey.discoveryEndpoint))
            }
            // No discoveryEndpoint — the `openId` sub-object *is* the document, so `tokenEndpoint`
            // becomes required; every other non-optional endpoint defaults to "" and the optional
            // ones to nil, matching the leniency the rest of the SDK already applies to those
            // fields.
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

        // Every successful call reconfigures the OpenID source, invalidating whatever was
        // materialized before: a replacement `openId` seeds the new document directly (nil when
        // this call has no `openId` block — discovery source); the discovery path likewise clears
        // any stale document so the next `oidcInitialize()` rediscovers instead of reapplying a
        // (possibly just-replaced) override to it. The applied-marker reset guarantees the
        // current effective override runs once against whichever document is materialized next.
        self.openId = seededOpenId
        self.openIdOverrideApplied = false

        // Replaces the JSON-derived override layer wholesale (never nests a new JSON override
        // under a stale one) whenever this call supplies an `openId` sub-object — including the
        // full-replacement case, where any override layer from a prior discovery-based
        // configuration is cleared since the new document is already complete. When this call's
        // JSON has no `openId` key at all, the JSON-derived layer (and any programmatic override)
        // are left unchanged.
        if openIdDict != nil {
            if parsedOpenIdOverrides.isEmpty {
                self.jsonOpenIdOverride = nil
            } else {
                let overrides = parsedOpenIdOverrides
                self.jsonOpenIdOverride = { openId in
                    for (key, setter) in OidcClientConfig.endpointSetters {
                        if let v = overrides[key] { setter(&openId, v) }
                    }
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
