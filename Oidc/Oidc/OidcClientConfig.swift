//
//  OidcClientConfig.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingLogger
import PingStorage

/// Configuration class for OIDC client.
public class OidcClientConfig {
    /// OpenID configuration.
    public var openId: OpenIdConfiguration?
    /// Token refresh threshold in seconds.
    public var refreshThreshold: Int64 = 0
    /// Agent delegate for handling OIDC operations.
    internal var agent: (any AgentDelegateProtocol)?
    /// Logger instance for logging.
    public var logger: Logger
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
    /// HTTP client for making network requests.
    public var httpClient: HttpClient?
  
    /// Initializes a new `OidcClientConfig` instance.
    public init() {
        logger = LogManager.none
        storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE", encryptor: SecuredKeyEncryptor() ?? NoEncryptor(), cacheable: true)
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
    public func oidcInitialize() async throws   {
        if httpClient == nil {
            httpClient = HttpClient()
        }
    
        if openId != nil {
            return
        }
        
        openId = try await discover()
    }
  
    /// Discovers the OpenID configuration from the discovery endpoint.
    /// - Returns: The discovered OpenID configuration.
    private func discover() async throws -> OpenIdConfiguration?  {
        guard URL(string: discoveryEndpoint) != nil else {
            logger.e("Invalid Discovery URL", error: nil)
            return nil
        }
        
        guard let httpClient else {
            logger.e("Invalid Http Client URL", error: nil)
            return nil
        }
        let request = Request()
        request.url(discoveryEndpoint)
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 500, message: String(decoding: data, as: UTF8.self))
        }
        let configuration = try JSONDecoder().decode(OpenIdConfiguration.self, from: data)
        return configuration
    }
  
    /// Clones the current configuration.
    /// - Returns: A new instance of OidcClientConfig with the same properties.
    public func clone() -> OidcClientConfig {
        let cloned = OidcClientConfig()
        cloned.update(with: self)
        return cloned
    }
  
    /// Merges another configuration into this one.
    /// - Parameter other: The other configuration to merge.
    func update(with other: OidcClientConfig) {
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
        self.httpClient = other.httpClient
    }
}
