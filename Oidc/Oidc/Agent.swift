//
//  Agent.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// The `Agent` is a protocol that is used to authenticate and end a session with an OpenID Connect provider.
/// `T` is the configuration object that is used to configure the `Agent`.
public protocol Agent<T>: Sendable {
     associatedtype T
     
     /// Provides the configuration object for the `Agent`.
     /// - Returns: A function that returns the configuration object.
     func config() -> () -> T
     
     /// End the session with the OpenID Connect provider.
     /// Best effort is made to end the session.
     func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool
     
     /// Authorize the `Agent` with the OpenID Connect provider.
     /// Before returning the `AuthCode`, the agent should verify the response from the OpenID Connect provider.
     /// For example, the agent should verify the state parameter in the response.
     /// - Parameter oidcConfig: The configuration for the OpenID Connect client.
     /// - Returns: `AuthCode` instance
     func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode
}


/// Allow the `Agent` to run on `OidcConfig` so that it can access the configuration object.
public class OidcConfig<T> {
     let oidcClientConfig: OidcClientConfig
     let config: T
     
     /// Initialize the `OidcConfig` with the `OidcClientConfig` and the configuration object.
     /// - Parameters:
     ///   - oidcClientConfig: The client configuration for the OpenID Connect provider.
     ///   - config: The configuration object.
     init(oidcClientConfig: OidcClientConfig, config: T) {
          self.oidcClientConfig = oidcClientConfig
          self.config = config
     }
}


/// Default implementation of the  `Agent` interface.
public final class DefaultAgent: Agent {
     
     public typealias T = Void
     
     /// Initialize the `DefaultAgent`.
     public init() {}
     
     /// Provides an empty configuration for the `DefaultAgent`.
     /// - Returns: A function that returns Void
     public func config() -> () -> Void {
          return {}
     }
     
     /// End the session with the OpenID Connect provider. This implementation always returns false.
     /// - Parameters:
     ///   - oidcConfig: The configuration for the OpenID Connect client.
     ///   - idToken: The ID token used to end the session.
     /// - Returns: Always returns false.
     @discardableResult
     public func endSession(oidcConfig: OidcConfig<Void>, idToken: String) async throws -> Bool {
          return false
     }
     
     /// Authorize the `DefaultAgent` with the OpenID Connect provider.
     /// This implementation always throws an `OidcError.authorizeError` error.
     /// - Parameter oidcConfig: The configuration for the OpenID Connect client.
     /// - Returns: Never returns normally.
     public func authorize(oidcConfig: OidcConfig<Void>) async throws -> AuthCode {
          throw OidcError.authorizeError(message: "No AuthCode is available.")
     }
}


/// Delegate protocol to dispatch `Agent` functions
public protocol AgentDelegateProtocol {
     associatedtype T
     func authenticate() async throws -> AuthCode
     func endSession(idToken: String) async throws -> Bool
}


/// Delegate class to dispatch `Agent` functions
public class AgentDelegate<T: Any>: AgentDelegateProtocol  {
     let agent: any Agent<T>
     let oidcConfig: OidcConfig<T>
     
     /// Initialize the `AgentDelegate` with an `Agent` and the configuration object.
     /// - Parameters:
     ///   - agent: The `Agent` instance.
     ///   - agentConfig: The configuration object for the `Agent`.
     ///   - oidcClientConfig: The `OidcClientConfig` instance.
     init(agent: any Agent<T>, agentConfig: T, oidcClientConfig: OidcClientConfig) {
          self.agent = agent
          self.oidcConfig = OidcConfig(oidcClientConfig: oidcClientConfig, config: agentConfig)
     }
     
     /// Authenticate with the OpenID Connect provider.
     /// - Returns: The authorization code.
     public func authenticate() async throws -> AuthCode {
          return try await self.agent.authorize(oidcConfig: oidcConfig)
     }
     
     /// End the session with the OpenID Connect provider.
     /// - Parameter idToken: The ID token used to end the session.
     /// - Returns: A boolean indicating whether the session was successfully ended.
     @discardableResult
     public func endSession(idToken: String) async throws -> Bool {
          return try await agent.endSession(oidcConfig: oidcConfig, idToken: idToken)
     }
}
