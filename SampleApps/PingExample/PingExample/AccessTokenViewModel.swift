//
//  AccessTokenViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOidc

/// The result of an access token fetch for a single tab.
struct AccessTokenResult {
    var info: String = ""
    var error: String? = nil
    var isLoading: Bool = true
    /// Whether a session exists despite the token error (enables Get Token action).
    var hasSession: Bool = false
}

/// Fetches, refreshes, revokes, and re-fetches access tokens for all three auth flows.
@MainActor
class AccessTokenViewModel: ObservableObject {
    /// Per-tab access token results, keyed by authentication type.
    @Published var results: [AuthTab: AccessTokenResult] = [
        .journey: AccessTokenResult(),
        .davinci: AccessTokenResult(),
        .oidc: AccessTokenResult(),
        .device: AccessTokenResult()
    ]
    
    init() {
        Task {
            await fetchAllTokens()
        }
    }
    
    /// Fetches tokens for all tabs concurrently.
    func fetchAllTokens() async {
        await withTaskGroup(of: (AuthTab, AccessTokenResult).self) { group in
            group.addTask { await (.journey, self.fetchToken(for: .journey)) }
            group.addTask { await (.davinci, self.fetchToken(for: .davinci)) }
            group.addTask { await (.oidc, self.fetchToken(for: .oidc)) }
            group.addTask { await (.device, self.fetchToken(for: .device)) }

            for await (tab, result) in group {
                results[tab] = result
            }
        }
    }
    
    private func fetchToken(for tab: AuthTab) async -> AccessTokenResult {
        let user: User?
        switch tab {
        case .journey:
            user = await ConfigurationManager.shared.journeyUser
        case .davinci:
            user = await ConfigurationManager.shared.davinciUser
        case .oidc:
            user = await ConfigurationManager.shared.oidcUser
        case .device:
            user = await ConfigurationManager.shared.deviceUser
        }
        
        guard let user = user else {
            return AccessTokenResult(info: "", error: "No session, please start \(tab.rawValue) flow to authenticate.", isLoading: false)
        }
        
        let token = await user.token()
        switch token {
        case .success(let token):
            let description = String(describing: token)
            LogManager.standard.i("\(tab.rawValue) AccessToken: \(description)")
            return AccessTokenResult(info: description, isLoading: false)
        case .failure(let error):
            LogManager.standard.e("", error: error)
            return AccessTokenResult(info: "", error: error.localizedDescription, isLoading: false)
        }
    }
    
    /// Refreshes the access token for the given tab.
    func refresh(tab: AuthTab) async {
        let user = await userFor(tab: tab)
        guard let user = user else { return }
        
        let result = await user.refresh()
        switch result {
        case .success(let token):
            let description = String(describing: token)
            LogManager.standard.i("\(tab.rawValue) Refreshed: \(description)")
            results[tab] = AccessTokenResult(info: description, isLoading: false)
        case .failure(let error):
            LogManager.standard.e("Refresh failed", error: error)
            results[tab] = AccessTokenResult(info: "", error: error.localizedDescription, isLoading: false)
        }
    }
    
    /// Revokes the access token for the given tab and checks if the session persists.
    func revoke(tab: AuthTab) async {
        let user = await userFor(tab: tab)
        guard let user = user else { return }
        
        await user.revoke()
        LogManager.standard.i("\(tab.rawValue) token revoked")
        let sessionStillActive = await userFor(tab: tab) != nil
        results[tab] = AccessTokenResult(info: "", error: "Token revoked.", isLoading: false, hasSession: sessionStillActive)
    }
    
    /// Re-fetches the token for the given tab (used after revoke when a session still exists).
    func getToken(tab: AuthTab) async {
        results[tab] = AccessTokenResult()
        results[tab] = await fetchToken(for: tab)
    }
    
    private func userFor(tab: AuthTab) async -> User? {
        switch tab {
        case .journey:
            return await ConfigurationManager.shared.journeyUser
        case .davinci:
            return await ConfigurationManager.shared.davinciUser
        case .oidc:
            return await ConfigurationManager.shared.oidcUser
        case .device:
            return await ConfigurationManager.shared.deviceUser
        }
    }
}
