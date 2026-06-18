//
//  ConfigurationManager.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import SwiftUI
import UIKit
import PingOidc
import PingJourney
import PingDavinci
import PingOrchestrate
import PingStorage
import PingOath
import PingPush
import PingLogger

//The ConfigurationManager class is used to manage the configuration settings for the SDK.
//The class provides the following functionality:
//   - Manage per-type configuration selections (Journey, DaVinci, OIDC Web)
//   - Build and cache optional SDK instances (Journey?, DaVinci?, OidcWebClient?)
//   - Rebuild instances on configuration switch
//   - Gracefully handle missing configurations (nil SDK instances)
//   - CRUD operations for configurations with UserDefaults persistence
//   - Provide user/session accessors

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    private static let selectionKeys: [ConfigType: String] = [
        .journey: "SelectedJourneyConfigName",
        .davinci: "SelectedDaVinciConfigName",
        .oidcWeb: "SelectedOidcWebConfigName",
        .device: "SelectedDeviceConfigName"
    ]
    
    private static let userConfigsKey = "UserConfigurations"

    // MARK: - Configurations
    
    /// All available configurations (defaults + user-added).
    @Published public var configurations: [Configuration]

    // MARK: - Per-Type Selections
    
    /// Tracks the selected configuration for each type.
    @Published public var selections: [ConfigType: Configuration]
    
    // MARK: - SDK Instances (rebuilt on config switch)
    
    public var journey: Journey?
    public var davinci: DaVinci?
    public var oidcLogin: OidcWebClient?
    public var deviceClient: OidcDeviceClient?

    // MFA Clients
    public var oathClient: OathClient?
    public var pushClient: PushClient?
    
    // MFA Services
    public var oathTimerService: OathTimerService?
    
    // Thread safety - use actor for initialization synchronization
    private let initActor = ClientInitializationActor()

    // MARK: - Init
    
    private init() {
        let allConfigs = ConfigurationManager.loadConfigurations()
        self.configurations = allConfigs
        
        let journeyConfig = ConfigurationManager.loadSelection(for: .journey, from: allConfigs)
        let davinciConfig = ConfigurationManager.loadSelection(for: .davinci, from: allConfigs)
        let oidcWebConfig = ConfigurationManager.loadSelection(for: .oidcWeb, from: allConfigs)
        let deviceConfig = ConfigurationManager.loadSelection(for: .device, from: allConfigs)

        var sels = [ConfigType: Configuration]()
        if let c = journeyConfig { sels[.journey] = c }
        if let c = davinciConfig { sels[.davinci] = c }
        if let c = oidcWebConfig { sels[.oidcWeb] = c }
        if let c = deviceConfig { sels[.device] = c }
        self.selections = sels

        self.journey = journeyConfig.map { config in
            ConfigurationManager.resolveJson(for: config)
                .flatMap { ConfigurationManager.buildJourney(fromJSON: $0) }
                ?? ConfigurationManager.buildJourney(config)
        }
        self.davinci = davinciConfig.map { config in
            ConfigurationManager.resolveJson(for: config)
                .flatMap { ConfigurationManager.buildDaVinci(fromJSON: $0) }
                ?? ConfigurationManager.buildDaVinci(config)
        }
        self.oidcLogin = oidcWebConfig.map { config in
            ConfigurationManager.resolveJson(for: config)
                .flatMap { ConfigurationManager.buildOidcWebClient(fromJSON: $0) }
                ?? ConfigurationManager.buildOidcWebClient(config)
        }
        self.deviceClient = deviceConfig.map { config in
            ConfigurationManager.resolveJson(for: config)
                .flatMap { ConfigurationManager.buildDeviceClient(fromJSON: $0) }
                ?? ConfigurationManager.buildDeviceClient(config)
        }
    }
    
    // MARK: - Configuration Selection
    
    /// Select a new configuration. Persists the per-type selection and rebuilds the relevant SDK instance.
    public func select(_ config: Configuration) {
        selections[config.type] = config
        if let key = ConfigurationManager.selectionKeys[config.type] {
            UserDefaults.standard.set(config.name, forKey: key)
        }
        
        // Rebuild only the SDK instance matching this config's type
        rebuildInstance(for: config)
    }
    
    /// Returns the selected configuration for the given type, if any.
    public func selectedConfig(for type: ConfigType) -> Configuration? {
        return selections[type] ?? configurations.first(where: { $0.type == type })
    }
    
    /// Whether at least one configuration exists for the given type.
    public func hasConfiguration(for type: ConfigType) -> Bool {
        return configurations.contains(where: { $0.type == type })
    }
    
    private func rebuildInstance(for config: Configuration) {
        let json = ConfigurationManager.resolveJson(for: config)
        switch config.type {
        case .journey:
            journey = json.flatMap { ConfigurationManager.buildJourney(fromJSON: $0) }
                ?? ConfigurationManager.buildJourney(config)
        case .davinci:
            davinci = json.flatMap { ConfigurationManager.buildDaVinci(fromJSON: $0) }
                ?? ConfigurationManager.buildDaVinci(config)
        case .oidcWeb:
            oidcLogin = json.flatMap { ConfigurationManager.buildOidcWebClient(fromJSON: $0) }
                ?? ConfigurationManager.buildOidcWebClient(config)
        case .device:
            deviceClient = json.flatMap { ConfigurationManager.buildDeviceClient(fromJSON: $0) }
                ?? ConfigurationManager.buildDeviceClient(config)
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new configuration and persist.
    public func addConfiguration(_ config: Configuration) {
        configurations.append(config)
        saveUserConfigurations()
        // If this is the first config of its type, auto-select it
        if selections[config.type] == nil {
            select(config)
        }
    }
    
    /// Update an existing configuration by name and persist.
    public func updateConfiguration(oldName: String, with config: Configuration) {
        if let index = configurations.firstIndex(where: { $0.name == oldName }) {
            configurations[index] = config
            saveUserConfigurations()
            // If this was the selected config for its type, re-select to rebuild the SDK instance
            if selections[config.type]?.name == oldName {
                select(config)
            }
        }
    }
    
    /// Delete a configuration by name and persist.
    public func deleteConfiguration(_ config: Configuration) {
        configurations.removeAll { $0.name == config.name && $0.type == config.type }
        saveUserConfigurations()
        // If the deleted config was selected, fall back to the first of its type (or clear)
        if selections[config.type]?.name == config.name {
            if let fallback = configurations.first(where: { $0.type == config.type }) {
                select(fallback)
            } else {
                selections.removeValue(forKey: config.type)
                if let key = ConfigurationManager.selectionKeys[config.type] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                switch config.type {
                case .journey: journey = nil
                case .davinci: davinci = nil
                case .oidcWeb: oidcLogin = nil
                case .device: deviceClient = nil
                }
            }
        }
    }
    
    // MARK: - User / Session Accessors

    public var journeyUser: User? {
        get async {
            return await journey?.journeyUser()
        }
    }

    public var deviceUser: User? {
        get async {
            return await deviceClient?.user()
        }
    }
    
    public var davinciUser: User? {
        get async {
            return await davinci?.daVinciUser()
        }
    }
    
    public var oidcUser: User? {
        get async {
            return await oidcLogin?.oidcLoginUser()
        }
    }
    
    public var journeySession: SSOToken? {
        get async {
            return await journey?.session()
        }
    }
    
    // MARK: - Factory Methods
    
    private static func buildJourney(_ config: Configuration) -> Journey {
        Journey.createJourney { journeyConfig in
            journeyConfig.serverUrl = config.serverUrl
            journeyConfig.realm = config.realm ?? "root"
            journeyConfig.cookie = config.cookieName ?? ""
            journeyConfig.logger = LogManager.standard
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = config.clientId
                oidcValue.scopes = Set<String>(config.scopes)
                oidcValue.redirectUri = config.redirectUri
                oidcValue.discoveryEndpoint = config.discoveryEndpoint
                oidcValue.storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE_JOURNEY")
                oidcValue.logger = LogManager.standard
                oidcValue.par = config.par ?? false
            }
        }
    }
    
    private static func buildDaVinci(_ config: Configuration) -> DaVinci {
        DaVinci.createDaVinci { daVinciConfig in
            daVinciConfig.logger = LogManager.standard
            daVinciConfig.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = config.clientId
                oidcValue.scopes = Set<String>(config.scopes)
                oidcValue.redirectUri = config.redirectUri
                oidcValue.discoveryEndpoint = config.discoveryEndpoint
                oidcValue.acrValues = config.acrValues ?? ""
                oidcValue.storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE_DAVINCI")
                oidcValue.par = config.par ?? false
            }
        }
    }
    
    private static func buildOidcWebClient(_ config: Configuration) -> OidcWebClient {
        OidcWebClient.createOidcWebClient { webConfig in
            webConfig.browserMode = .login
            webConfig.browserType = .sfViewController
            webConfig.logger = LogManager.standard
            webConfig.module(PingOidc.OidcModule.config) { oidcValue in
                oidcValue.clientId = config.clientId
                oidcValue.scopes = Set<String>(config.scopes)
                oidcValue.redirectUri = config.redirectUri
                oidcValue.discoveryEndpoint = config.discoveryEndpoint
                oidcValue.acrValues = config.acrValues ?? ""
                oidcValue.storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE_OIDCWEB")
                oidcValue.par = config.par ?? false
            }
        }
    }
    
    private static func buildDeviceClient(_ config: Configuration) -> OidcDeviceClient {
        OidcDeviceClient.createOidcDeviceClient { oidcConfig in
            oidcConfig.clientId = config.clientId
            oidcConfig.scopes = Set<String>(config.scopes)
            oidcConfig.redirectUri = config.redirectUri
            oidcConfig.discoveryEndpoint = config.discoveryEndpoint
            oidcConfig.storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE_DEVICE")
            oidcConfig.logger = LogManager.standard
            oidcConfig.openIdOverride = { openId in
                if config.deviceAuthorizationEndpoint != nil {
                    openId.deviceAuthorizationEndpoint = config.deviceAuthorizationEndpoint
                }
            }
        }
    }

    // MARK: - JSON Factory Helpers (Unified SDK Configuration)

    /// Creates a Journey from a unified JSON configuration dictionary.
    ///
    /// Example JSON mirrors the cross-platform schema defined in the Unified SDK Configuration spec.
    /// Use this when loading configuration from a remote source, a shared file, or a CI environment.
    ///
    ///     let json: [String: Any] = [
    ///         "journey": [
    ///             "serverUrl": "https://example.com/am",
    ///             "realm": "alpha"
    ///         ],
    ///         "timeout": 30000,
    ///         "log": "DEBUG",
    ///         "oidc": [                          // optional for Journey
    ///             "clientId": "my-client",
    ///             "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
    ///             "scopes": ["openid", "profile", "email"],
    ///             "redirectUri": "myapp://callback"
    ///         ]
    ///     ]
    ///     let result = ConfigurationManager.buildJourney(fromJSON: json)
    static func buildJourney(fromJSON json: [String: Any]) -> Journey? {
        switch Journey.createJourney(json: json) {
        case .success(let journey):
            return journey
        case .failure(let error):
            LogManager.logger.e("Failed to create Journey from JSON: \(error.localizedDescription)", error: error)
            return nil
        }
    }

    /// Creates a DaVinci from a unified JSON configuration dictionary.
    ///
    /// Example JSON mirrors the cross-platform schema defined in the Unified SDK Configuration spec.
    ///
    ///     let json: [String: Any] = [
    ///         "timeout": 15000,
    ///         "oidc": [
    ///             "clientId": "my-client",
    ///             "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
    ///             "scopes": ["openid", "profile", "email"],
    ///             "redirectUri": "myapp://callback"
    ///         ]
    ///     ]
    ///     let result = ConfigurationManager.buildDaVinci(fromJSON: json)
    static func buildDaVinci(fromJSON json: [String: Any]) -> DaVinci? {
        switch DaVinci.createDaVinci(json: json) {
        case .success(let daVinci):
            return daVinci
        case .failure(let error):
            LogManager.logger.e("Failed to create DaVinci from JSON: \(error.localizedDescription)", error: error)
            return nil
        }
    }

    /// Creates an OidcWebClient from a unified JSON configuration dictionary.
    static func buildOidcWebClient(fromJSON json: [String: Any]) -> OidcWebClient? {
        switch OidcWebClient.createOidcWebClient(json: json) {
        case .success(let client):
            return client
        case .failure(let error):
            LogManager.logger.e("Failed to create OidcWebClient from JSON: \(error.localizedDescription)", error: error)
            return nil
        }
    }

    /// Creates an OidcDeviceClient from a unified JSON configuration dictionary.
    static func buildDeviceClient(fromJSON json: [String: Any]) -> OidcDeviceClient? {
        switch OidcDeviceClient.createOidcDeviceClient(json: json) {
        case .success(let client):
            return client
        case .failure(let error):
            LogManager.logger.e("Failed to create OidcDeviceClient from JSON: \(error.localizedDescription)", error: error)
            return nil
        }
    }

    // MARK: - Persistence Helpers
    
    /// Loads all configurations: defaults, bundled JSON files, then user-added configs from UserDefaults.
    private static func loadConfigurations() -> [Configuration] {
        var configs = defaultConfigurations
        configs.append(contentsOf: JsonConfigLoader.load())
        if let data = UserDefaults.standard.data(forKey: userConfigsKey),
           let userConfigs = try? JSONDecoder().decode([Configuration].self, from: data) {
            configs.append(contentsOf: userConfigs)
        }
        return configs
    }

    /// Returns the parsed JSON dictionary for a JSON-backed config, or nil for non-JSON configs.
    private static func resolveJson(for config: Configuration) -> [String: Any]? {
        guard let filename = config.jsonFileName else { return nil }
        return loadBundledJson(filename)
    }

    private static var jsonCache: [String: [String: Any]] = [:]

    /// Loads a bundled JSON file by filename and returns its parsed dictionary.
    private static func loadBundledJson(_ filename: String) -> [String: Any]? {
        if let cached = jsonCache[filename] { return cached }
        let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Configs"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        jsonCache[filename] = json
        return json
    }
    
    /// Persists user-added configurations (non-defaults, non-JSON) to UserDefaults.
    private func saveUserConfigurations() {
        let userConfigs = configurations.filter { !$0.isDefault && !$0.isJsonBased }
        if let data = try? JSONEncoder().encode(userConfigs) {
            UserDefaults.standard.set(data, forKey: ConfigurationManager.userConfigsKey)
        }
    }
    
    /// Loads the persisted selection for a given type, falling back to the first config of that type.
    private static func loadSelection(for type: ConfigType, from configs: [Configuration]) -> Configuration? {
        if let key = selectionKeys[type],
           let savedName = UserDefaults.standard.string(forKey: key),
           let config = configs.first(where: { $0.name == savedName && $0.type == type }) {
            return config
        }
        return configs.first(where: { $0.type == type })
    }

    // MARK: - MFA Client Initialization

    /// Initialize the OATH client for MFA functionality
    public func initializeOathClient() async throws {
        let client = try await initActor.initializeOath {
            try await OathClient.createClient { config in
                config.logger = LogManager.logger
            }
        }
        
        if let client = client {
            self.oathClient = client
            self.oathTimerService = OathTimerService(client: client)
        }
    }

    /// Initialize the Push client for MFA functionality
    public func initializePushClient() async throws {
        let client = try await initActor.initializePush {
            try await PushClient.createClient { config in
                config.logger = LogManager.logger
            }
        }
        
        if let client = client {
            self.pushClient = client
        }
    }
}

// MARK: - Actor for Thread-Safe Initialization

private actor ClientInitializationActor {
    private var isOathInitializing = false
    private var isPushInitializing = false
    private var oathInitialized = false
    private var pushInitialized = false
    
    func initializeOath(factory: @Sendable () async throws -> OathClient) async throws -> OathClient? {
        guard !oathInitialized && !isOathInitializing else { return nil }
        
        isOathInitializing = true
        defer { isOathInitializing = false }
        
        let client = try await factory()
        oathInitialized = true
        return client
    }
    
    func initializePush(factory: @Sendable () async throws -> PushClient) async throws -> PushClient? {
        guard !pushInitialized && !isPushInitializing else { return nil }
        
        isPushInitializing = true
        defer { isPushInitializing = false }
        
        let client = try await factory()
        pushInitialized = true
        return client
    }
}

//Extensions
extension ObservableObject {
    @MainActor
    var topViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topController = keyWindow.rootViewController else {
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}

extension Binding {
    func toUnwrapped<T: Sendable>(defaultValue: T) -> Binding<T> where Value == Optional<T>  {
        Binding<T>(get: { self.wrappedValue ?? defaultValue }, set: { self.wrappedValue = $0 })
    }
}
