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
    /// Published property to control whether to show the journey name input screen
    @Published public var showJourneyNameInput: Bool = true

    /// Initializes the view model but does NOT automatically start the journey.
    /// The journey will start when the user enters a journey name.
    init() {
        // Remove auto-start - let user enter journey name first
    }

    /// Starts the Journey orchestration process with a specific journey name.
    /// - Parameter journeyName: The name of the journey to start
    public func startJourney(with journeyName: String) async {
        guard !journeyName.isEmpty else { return }

        await MainActor.run {
            isLoading = true
        }
        
        let next = await journey.start(journeyName) { options in
            options.forceAuth = false
            options.noSession = false
        }

        await MainActor.run {
            self.state = JourneyState(node: next)
            self.showJourneyNameInput = false
            self.isLoading = false
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
    
    public func refresh() {
        state = JourneyState(node: state.node)
    }

    /// Reset the view model to show journey name input again
    public func reset() {
        showJourneyNameInput = true
        state = JourneyState()
        isLoading = false
    }

    func getSavedJourneyName() -> String {
        // Retrieve the saved journey name from storage
        UserDefaults.standard.string(forKey: "journeyName") ?? ""
    }

    func saveJourneyName(_ journeyName: String) {
        // Save the journey name to storage
        UserDefaults.standard.set(journeyName, forKey: "journeyName")
    }
}

/// A model class that represents the state of the current and previous nodes in the Journey flow.
class JourneyState {
    var node: Node? = nil

    init(node: Node? = nil) {
        self.node = node
    }
}


