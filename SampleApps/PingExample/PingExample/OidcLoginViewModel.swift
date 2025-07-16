// 
//  OidcLoginViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingOidc

public let oidLogin = OidcLogin.createOidcLogin { config in
    let currentConfig = ConfigurationManager.shared.currentConfigurationViewModel
    //config.cookie = currentConfig?.cookieName ?? "" //TODO: need add cookie  support
    config.module(PingOidc.OidcModule.config) { oidcValue in
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
class OidcLoginViewModel: ObservableObject {
    /// Published property that holds the current state node data.
    @Published public var state: Result<User, OidcError>?
    /// Published property to track whether the view is currently loading.
    @Published public var isLoading: Bool = false
    
    /// Initializes the view model and starts the Journey orchestration process.
    init() {
        Task {
            self.state = try await oidLogin.authorize()
        }
    }
}
