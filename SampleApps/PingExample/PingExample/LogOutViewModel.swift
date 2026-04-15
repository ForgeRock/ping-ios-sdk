// 
//  LogOutViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingOidc

/// Represents an active authentication session displayed in the logout screen.
struct SessionInfo: Identifiable {
    let id = UUID()
    let tab: AuthTab
    let title: String
    let description: String
}

/// Discovers active sessions across all auth flows (Journey, DaVinci, OIDC)
/// and provides individual and bulk logout operations.
@MainActor
class LogOutViewModel: ObservableObject {
    /// Currently active authentication sessions.
    @Published var activeSessions: [SessionInfo] = []
    @Published var isLoading: Bool = true
    
    init() {
        Task {
            await loadSessions()
        }
    }
    
    /// Checks each auth flow for an active session and populates `activeSessions`.
    func loadSessions() async {
        isLoading = true
        var sessions: [SessionInfo] = []
        
        if await ConfigurationManager.shared.journeyUser != nil {
            sessions.append(SessionInfo(tab: .journey, title: "Journey", description: "Authenticated via Ping Journey"))
        }
        if await ConfigurationManager.shared.davinciUser != nil {
            sessions.append(SessionInfo(tab: .davinci, title: "DaVinci", description: "Authenticated via PingOne DaVinci"))
        }
        if await ConfigurationManager.shared.oidcUser != nil,
           case .success = await ConfigurationManager.shared.oidcUser?.token() {
            sessions.append(SessionInfo(tab: .oidc, title: "OIDC (Web)", description: "Authenticated via OpenID Connect"))
        }
        
        activeSessions = sessions
        isLoading = false
    }
    
    /// Logs out a single session and removes it from the active list.
    func logout(session: SessionInfo) async {
        switch session.tab {
        case .journey:
            await ConfigurationManager.shared.journeyUser?.logout()
        case .davinci:
            await ConfigurationManager.shared.davinciUser?.logout()
        case .oidc:
            await ConfigurationManager.shared.oidcUser?.logout()
        }
        activeSessions.removeAll { $0.tab == session.tab }
    }
    
    /// Logs out all active sessions across Journey, DaVinci, and OIDC.
    func logoutAll() async {
        await ConfigurationManager.shared.journeyUser?.logout()
        await ConfigurationManager.shared.davinciUser?.logout()
        await ConfigurationManager.shared.oidcUser?.logout()
        activeSessions.removeAll()
    }
}
