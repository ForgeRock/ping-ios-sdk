// 
//  OidcLoginViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingOidc
import PingLogger
import PingStorage

/// Proxy to the current OidcWebClient instance managed by ConfigurationManager.
/// Returns nil when no OIDC (Web) configuration exists.
/// Rebuilt automatically when the selected configuration changes.
@MainActor
public var oidcLogin: OidcWebClient? { ConfigurationManager.shared.oidcLogin }

// A view model that manages the flow and state of the OIDC Web login process.
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
            guard let oidcLogin = oidcLogin else { return }
            self.state = try await oidcLogin.authorize { options in
                options.additionalParameters = ["foo": "bar"]
            }
        }
    }
}
