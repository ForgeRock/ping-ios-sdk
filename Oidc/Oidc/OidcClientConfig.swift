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

/// Coordinates concurrent `oidcInitialize()` calls on the same instance so simultaneous
/// first-use callers share one in-flight initialization instead of independently racing through
/// discovery and `openIdOverride` application.
///
/// - Important: Cancelling any one caller's surrounding task cancels the shared discovery and
///   `openIdOverride` work for every caller currently waiting on it — there is no way to abandon
///   only one caller's interest while leaving the operation running for the others. A caller that
///   happens to share an in-flight operation with another caller can therefore fail with a
///   cancellation-derived error triggered by a caller other than itself. This trades a rare
///   cross-caller failure for promptly honouring cancellation in the common case of a single
///   caller waiting on its own `oidcInitialize()` call.
private actor OidcInitializationCoordinator {
    private var inFlightTask: Task<Void, any Error>?

    /// Runs `operation` at most once concurrently: a caller that finds no task in flight starts
    /// one and awaits it; a caller that finds one already running awaits that same task instead
    /// of starting a second discovery/override cycle.
    ///
    /// Cancelling the calling task cancels the shared `operation` itself (see the class-level
    /// note), so the next call after a cancellation-induced failure also starts fresh.
    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        let task = currentOrNewTask(operation)
        try await Self.awaitCancellably(task)
    }

    /// Returns the task currently in flight, or creates one. The created task clears
    /// `inFlightTask` itself, from inside its own body, as the very last thing it does before
    /// completing — not as a side effect of whichever caller's own continuation happens to resume
    /// first. Because that clear runs strictly before the task's own completion, and `task.value`
    /// cannot resolve for *any* caller until the task has fully completed, every caller — including
    /// one that arrives only after every existing caller has already seen the result — is
    /// guaranteed to see `inFlightTask == nil` by the time it could possibly retry, so a retry
    /// immediately after a failure always starts a genuinely fresh attempt instead of ever
    /// rejoining a task that has already finished.
    private func currentOrNewTask(_ operation: @escaping @Sendable () async throws -> Void) -> Task<Void, any Error> {
        if let inFlightTask {
            return inFlightTask
        }

        let task = Task {
            do {
                try await operation()
                self.clearInFlightTask()
            } catch {
                self.clearInFlightTask()
                throw error
            }
        }
        inFlightTask = task
        return task
    }

    private func clearInFlightTask() {
        inFlightTask = nil
    }

    /// Awaits `task`, cancelling it if the calling context's own task is cancelled. `task.cancel()`
    /// is a plain, non-isolated call, so it can run directly from `onCancel` without hopping back
    /// onto this actor.
    private static func awaitCancellably(_ task: Task<Void, any Error>) async throws {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

/// Configuration class for OIDC client.
///
/// - Important: This class is `@unchecked Sendable` and contains mutable `var` fields.
///   Configure all properties before passing the instance to any client or workflow — do
///   not mutate it afterwards, as it may be read concurrently from background threads.
///   `oidcInitialize()` itself is the one exception: concurrent calls to it are coordinated so
///   they share a single discovery request and a single `openIdOverride` application.
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

    /// Shared by the `OidcError.configurationError` thrown from `discover()` and by its log line, so
    /// a consumer reads the same actionable text in the log and in the error.
    static let noOpenIdConfigurationMessage =
        "No OpenID configuration: set either `discoveryEndpoint` or `openId` on OidcClientConfig."

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
    /// Caller-supplied override, set directly via the public `openIdOverride` property below.
    private var programmaticOpenIdOverride: ((inout OpenIdConfiguration) -> Void)?
    /// Override synthesized from the most recently applied JSON `openId` sub-object. Replaced
    /// wholesale by `apply(json:)` whenever the JSON supplies an `openId` object (never nested
    /// under a prior JSON layer); left untouched when a JSON configuration omits `openId`.
    private var jsonOpenIdOverride: ((inout OpenIdConfiguration) -> Void)?
    /// Coordinates concurrent `oidcInitialize()` calls on this instance; see
    /// `OidcInitializationCoordinator`.
    private let initializationCoordinator = OidcInitializationCoordinator()

    /// Called once per materialized `OpenIdConfiguration` — after OpenID discovery completes or
    /// against a pre-supplied/JSON-seeded `openId` — allowing callers to patch any field before
    /// it is used (e.g. override `deviceAuthorizationEndpoint` for a non-standard server).
    ///
    /// Reading this property returns the programmatic override composed with any JSON-derived
    /// endpoint overrides installed by `apply(json:)`, with the JSON values applied second so
    /// they win for any endpoint key they cover. Assigning to it sets only the programmatic
    /// layer; the JSON-derived layer is managed separately by `apply(json:)` and is unaffected
    /// by reassignment.
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
    
    /// Initializes the lazy properties to their default values.
    ///
    /// Discovery is performed only when `openId` has not been supplied by the caller, so a
    /// pre-configured `OpenIdConfiguration` skips the network round-trip entirely. Whichever
    /// document ends up in `openId` — discovered or pre-supplied — is patched by the effective
    /// `openIdOverride` exactly once per materialized document, even though every `OidcClient`
    /// entry point re-enters this method.
    ///
    /// Concurrent calls on the same instance are coordinated: a caller that arrives while another
    /// is already discovering/applying the override awaits that same in-flight operation instead
    /// of issuing a second discovery request or reapplying the override a second time. Cancelling
    /// any one caller's own task cancels that shared operation for every caller currently waiting
    /// on it — see `OidcInitializationCoordinator`.
    ///
    /// - Throws: `OidcError.configurationError` when neither `openId` nor a usable
    ///   `discoveryEndpoint` is configured, or any error surfaced by discovery itself
    ///   (`OidcError.apiError`, a decoding failure, a transport error, `CancellationError` if this
    ///   or a concurrent caller cancels). A failure leaves `openId` `nil`, so a subsequent call
    ///   retries.
    public func oidcInitialize() async throws {
        try await initializationCoordinator.run {
            try await self.performOidcInitialization()
        }
    }

    /// The actual discover-then-override sequence, run at most once concurrently per instance
    /// via `initializationCoordinator`. See `oidcInitialize()`.
    private func performOidcInitialization() async throws {
        if httpClient == nil {
            httpClient = HttpClient.createClient()
        }

        if openId == nil {
            // A failed discovery throws, which leaves `openId` nil so a later call can retry.
            openId = try await discover()
        }

        if var configuration = openId, !openIdOverrideApplied {
            openIdOverride?(&configuration)
            openId = configuration
            openIdOverrideApplied = true
        }
    }
    
    /// Discovers the OpenID configuration from the discovery endpoint.
    ///
    /// Only the endpoint URL and static text are logged — never a response body.
    /// - Returns: The discovered OpenID configuration.
    /// - Throws: `OidcError.configurationError` when `discoveryEndpoint` is blank or malformed, or
    ///   when no HTTP client is available; `OidcError.apiError` when the endpoint responds with a
    ///   non-success status; a `DecodingError` when the response is not a discovery document.
    private func discover() async throws -> OpenIdConfiguration {
        guard URL(string: discoveryEndpoint) != nil else {
            let message = OidcClientConfig.noOpenIdConfigurationMessage
                + " Invalid discoveryEndpoint: \"\(discoveryEndpoint)\""
            logger.e(message, error: nil)
            throw OidcError.configurationError(message: message)
        }

        guard let httpClient else {
            let message = "No HTTP client available to fetch the OpenID configuration from \(discoveryEndpoint)"
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
    ///
    /// The programmatic and JSON-derived override layers, and the "already applied" flag, are
    /// carried over directly (not through the composed `openIdOverride` property), so a clone of
    /// an already-initialised configuration preserves both layers and does not re-run the
    /// effective override closure on a document that has already been patched.
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
    /// `discoveryEndpoint` is required unless an `openId` sub-object is supplied. When `openId` is
    /// supplied without `discoveryEndpoint` it replaces the discovery document (no network call) and
    /// `tokenEndpoint` becomes required. When both are supplied, discovery runs and `openId` patches
    /// the discovered document. A blank `discoveryEndpoint` counts as absent, since discovery can
    /// never succeed against it.
    ///
    /// - Important: A successful call reconfigures the OpenID source and invalidates any
    ///   previously materialized document, even if this instance was already initialized: the
    ///   `openId`-only path seeds the new document directly, and the discovery path clears
    ///   `openId` so the next `oidcInitialize()` rediscovers. The override-applied marker is reset
    ///   accordingly, so the current effective `openIdOverride` is guaranteed to run once against
    ///   whichever document is materialized next. A caller that needs a fully programmatic
    ///   `openId` document to survive a later `apply(json:)` call should set it directly again
    ///   afterwards rather than relying on it surviving reapplication.
    ///
    /// - Important: If the JSON contains an `openId` sub-object, its endpoint values **replace**
    ///   the JSON-derived layer of `openIdOverride` wholesale (never nested under a prior JSON
    ///   layer) and are applied on top of any programmatic override set directly via the public
    ///   `openIdOverride` property, so the JSON values win for any endpoint key they cover. If the
    ///   JSON contains no `openId` key, the JSON-derived layer — and any programmatic override —
    ///   are left unchanged.
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

        // Every successful `apply(json:)` reconfigures the OpenID source, invalidating any
        // previously materialized document: an `openId`-only JSON seeds it directly (no
        // discovery); a JSON with a usable `discoveryEndpoint` — with or without an `openId`
        // patch — clears it so the next `oidcInitialize()` rediscovers. The applied-marker reset
        // guarantees the current effective override runs once against whichever document is
        // materialized next.
        self.openId = seededOpenId
        self.openIdOverrideApplied = false

        // Replaces the JSON-derived override layer wholesale (never nests JSON A under JSON B)
        // when this JSON supplies an `openId` sub-object. A programmatic override set directly
        // via the public `openIdOverride` property, and any previously installed JSON layer when
        // this JSON omits `openId`, are left untouched.
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
