// 
//  LogOutViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingOidc

struct SessionInfo: Identifiable {
    let id = UUID()
    let tab: UserInfoTab
    let title: String
    let description: String
}

@MainActor
class LogOutViewModel: ObservableObject {
    @Published var activeSessions: [SessionInfo] = []
    @Published var isLoading: Bool = true
    
    init() {
        Task {
            await loadSessions()
        }
    }
    
    func loadSessions() async {
        isLoading = true
        var sessions: [SessionInfo] = []
        
        if await ConfigurationManager.shared.journeyUser != nil {
            sessions.append(SessionInfo(tab: .journey, title: "Journey Session", description: "Logout from ForgeRock Journey authentication"))
        }
        if await ConfigurationManager.shared.davinciUser != nil {
            sessions.append(SessionInfo(tab: .davinci, title: "DaVinci Session", description: "Logout from PingOne DaVinci authentication"))
        }
        if await ConfigurationManager.shared.oidcUser != nil,
           case .success = await ConfigurationManager.shared.oidcUser?.token() {
            sessions.append(SessionInfo(tab: .oidc, title: "OIDC Session", description: "Logout from OIDC Web authentication"))
        }
        
        activeSessions = sessions
        isLoading = false
    }
    
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
    
    func logoutAll() async {
        await ConfigurationManager.shared.journeyUser?.logout()
        await ConfigurationManager.shared.davinciUser?.logout()
        await ConfigurationManager.shared.oidcUser?.logout()
        activeSessions.removeAll()
    }
}
