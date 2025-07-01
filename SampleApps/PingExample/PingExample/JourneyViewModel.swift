//
//  JourneyViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate
import PingLogger
import PingStorage
import PingJourney

/// Configures and initializes the Journey instance with the AIC/AM server and OAuth 2.0 client details.
/// - This configuration includes:
///   - Client ID
///   - Scopes
///   - Redirect URI
///   - Discovery Endpoint
///   - Other optional fields



public let journey = Journey.createJourney { config in
    let currentConfig = ConfigurationManager.shared.currentConfigurationViewModel
    config.serverUrl = currentConfig?.serverUrl
    config.realm = currentConfig?.realm ?? "root"
    config.cookie = currentConfig?.cookieName ?? ""
    config.module(PingJourney.OidcModule.config) { oidcValue in
        oidcValue.clientId = currentConfig?.clientId ?? ""
        oidcValue.scopes = Set<String>(currentConfig?.scopes ?? [])
        oidcValue.redirectUri = currentConfig?.redirectUri ?? ""
        oidcValue.discoveryEndpoint = currentConfig?.discoveryEndpoint ?? ""
    }
}

// A view model that manages the flow and state of the Journey orchestration process.
/// - Responsible for:
///   - Starting the Journey flow
///   - Progressing to the next node in the flow
///   - Maintaining the current and previous flow state
///   - Handling loading states
@MainActor
class JourneyViewModel: ObservableObject {
    /// Published property that holds the current state node data.
    @Published public var state: JourneyState = JourneyState()
    /// Published property to track whether the view is currently loading.
    @Published public var isLoading: Bool = false
    
    /// Initializes the view model and starts the Journey orchestration process.
    init() {
        Task {
            await startJourney()
        }
    }
    
    /// Starts the Journey orchestration process.
    /// - Sets the initial node and updates the `data` property with the starting node.
    public func startJourney() async {
        
        await MainActor.run {
            isLoading = true
        }
        
        let next = await journey.start("Login") {
            $0.forceAuth = false
            $0.noSession = false
        }
        
        await MainActor.run {
            self.state = JourneyState(node: next)
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
                self.state = JourneyState(node: next)
                isLoading = false
            }
        }
    }
    
    public func shouldValidate(node: ContinueNode) -> Bool {
        let shouldValidate = false
        
        return shouldValidate
    }
    
    public func refresh() {
        state = JourneyState(node: state.node)
    }
}

/// A model class that represents the state of the current and previous nodes in the Journey flow.
class JourneyState {
    var node: Node? = nil
    
    init(node: Node? = nil) {
        self.node = node
    }
}
