//
//  DavinciViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingDavinci
import PingOidc
import PingOrchestrate
import PingLogger
import PingStorage
import PingExternalIdP
import PingJourney

/// Configures and initializes the DaVinci instance with the PingOne server and OAuth 2.0 client details.
/// - This configuration includes:
///   - Client ID
///   - Scopes
///   - Redirect URI
///   - Discovery Endpoint
///   - Other optional fields
public let davinci = DaVinci.createDaVinci { config in
    let currentConfig = ConfigurationManager.shared.currentConfigurationViewModel
    config.module(PingDavinci.OidcModule.config) { oidcValue in
        oidcValue.clientId = currentConfig?.clientId ?? ""
        oidcValue.scopes = Set<String>(currentConfig?.scopes ?? [])
        oidcValue.redirectUri = currentConfig?.redirectUri ?? ""
        oidcValue.discoveryEndpoint = currentConfig?.discoveryEndpoint ?? ""
        oidcValue.acrValues = "1557008a3c8b6105d5f4e8e053ac7a29" //update with actual ACR values if needed or remove
    }
}

// MARK: - Multi-User DaVinci Instances with Separate Cookie Storage
// The following examples demonstrate how to create multiple DaVinci instances
// with isolated cookie and token storage for different users or use cases.
//
// Key points:
// 1. Each DaVinci instance can have its own cookie storage via CookieModule.config
// 2. Each DaVinci instance can have its own token storage via OidcModule.config
// 3. Use unique account identifiers to keep storage completely separate
// 4. You must use CustomHTTPCookie array type for cookie storage

// Instance 1 - Standard authentication with long-lived tokens
/*
let standardDaVinciInstance = DaVinci.createDaVinci { config in
    
    config.module(CookieModule.config) { cookieConfig in
        cookieConfig.cookieStorage = KeychainStorage<[CustomHTTPCookie]>(account: "standard_storage", encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    config.module(PingDavinci.OidcModule.config) { oidcConfig in
        oidcConfig.clientId = "standard-client"
        oidcConfig.scopes = ["openid", "profile", "email"]
        oidcConfig.redirectUri = "app:/oauth2redirect"
        oidcConfig.discoveryEndpoint = "[DISCOVERY ENDPOINT]"
        oidcConfig.acrValues = "" //update with actual ACR values if needed or
        
        // Separate storage for this instance’s access token
        oidcConfig.storage = KeychainStorage<Token>(account: "standard_tokens")
    }

}

// Instance 2 - High-security transactions with short-lived tokens
// Switch "Journey.createJourney" to "DaVinci.createDaVinci" if required
let transactionDaVinciInstance = DaVinci.createDaVinci { config in
    
    config.module(CookieModule.config) { cookieConfig in
        cookieConfig.cookieStorage = KeychainStorage<[CustomHTTPCookie]>(account: "transaction_cookies", encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    config.module(PingDavinci.OidcModule.config) { oidcConfig in
        oidcConfig.clientId = "transaction-client"
        oidcConfig.scopes = ["openid", "transactions"]
        oidcConfig.redirectUri = "app:/oauth2redirect"
        oidcConfig.discoveryEndpoint = "[DISCOVERY ENDPOINT]"
        oidcConfig.acrValues = "" //update with actual ACR values if needed or remove
        
        // Separate storage for this instance’s access token
        oidcConfig.storage = KeychainStorage<Token>(account: "transaction_tokens")
    }

    // Uses the custom cookie storage configured above
}
*/

// A view model that manages the flow and state of the DaVinci orchestration process.
/// - Responsible for:
///   - Starting the DaVinci flow
///   - Progressing to the next node in the flow
///   - Maintaining the current and previous flow state
///   - Handling loading states
@MainActor
class DavinciViewModel: ObservableObject {
    /// Published property that holds the current state node data.
    @Published public var state: DavinciState = DavinciState()
    /// Published property to track whether the view is currently loading.
    @Published public var isLoading: Bool = false
    
    /// Initializes the view model and starts the DaVinci orchestration process.
    init() {
        Task {
            await startDavinci()
        }
    }
    
    /// Starts the DaVinci orchestration process.
    /// - Sets the initial node and updates the `data` property with the starting node.
    public func startDavinci() async {
        
        await MainActor.run {
            isLoading = true
        }
        
        // Starts the DaVinci orchestration process and retrieves the first node.
        let next = await davinci.start()
        await MainActor.run {
            self.state = DavinciState(node: next)
            isLoading = false
        }
    }
    
    /// Advances to the next node in the orchestration process.
    /// - Parameter node: The current node to progress from.
    public func next(node: Node) async {
        await MainActor.run {
            isLoading = true
        }
        if let current = node as? ContinueNode {
            // Retrieves the next node in the flow.
            let next = await current.next()
            await MainActor.run {
                self.state = DavinciState(node: next)
                isLoading = false
            }
        }
    }
    
    public func shouldValidate(node: ContinueNode) -> Bool {
        var shouldValidate = false
        for collector in node.collectors {
            // Check if the collector is a social collector and if it has a resume request.
            // In that case, we should not validate the collectors and continue with the submission of the flow.
            if let socialCollector = collector as? IdpCollector {
                if socialCollector.resumeRequest != nil {
                    shouldValidate = false
                    return shouldValidate
                }
            }
            if let collector = collector as? ValidatedCollector {
                if collector.validate().count > 0 {
                    shouldValidate = true
                }
            }
        }
        return shouldValidate
    }
    
    public func refresh() {
        state = DavinciState(node: state.node)
    }
}

/// A model class that represents the state of the current and previous nodes in the DaVinci flow.
class DavinciState {
    var node: Node? = nil
    
    init(node: Node? = nil) {
        self.node = node
    }
}

@MainActor
public class ValidationViewModel: ObservableObject {
    @Published var shouldValidate = false
}
