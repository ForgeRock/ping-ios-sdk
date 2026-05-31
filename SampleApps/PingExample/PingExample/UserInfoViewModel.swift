// 
//  UserInfoViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingLogger
import PingOidc

/// Authentication tab types used across multiple views (User Info, Access Token, Log Out).
/// Each case maps to an SDK auth flow with a display name and SF Symbol icon.
enum AuthTab: String, CaseIterable, Identifiable {
    case journey = "Journey"
    case davinci = "DaVinci"
    case oidc = "OIDC (Web)"
    case device = "Device Flow"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journey: return "map.fill"
        case .davinci: return "key.fill"
        case .oidc: return "lock.shield.fill"
        case .device: return "tv"
        }
    }
}

/// The result of a user info fetch for a single tab.
struct UserInfoResult {
    var info: String = ""
    var error: String? = nil
    var isLoading: Bool = true
}

/// Fetches user info concurrently for all three auth flows (Journey, DaVinci, OIDC)
/// and exposes per-tab results.
@MainActor
class UserInfoViewModel: ObservableObject {
    /// Per-tab user info results, keyed by authentication type.
    @Published var results: [AuthTab: UserInfoResult] = [
        .journey: UserInfoResult(),
        .davinci: UserInfoResult(),
        .oidc: UserInfoResult(),
        .device: UserInfoResult()
    ]
    
    init() {
        Task {
            await fetchAllUserInfo()
        }
    }
    
    /// Fetches user info for all tabs concurrently.
    func fetchAllUserInfo() async {
        await withTaskGroup(of: (AuthTab, UserInfoResult).self) { group in
            group.addTask { await (.journey, self.fetchUserInfo(for: .journey)) }
            group.addTask { await (.davinci, self.fetchUserInfo(for: .davinci)) }
            group.addTask { await (.oidc, self.fetchUserInfo(for: .oidc)) }
            group.addTask { await (.device, self.fetchUserInfo(for: .device)) }

            for await (tab, result) in group {
                results[tab] = result
            }
        }
    }
    
    private func fetchUserInfo(for tab: AuthTab) async -> UserInfoResult {
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
            return UserInfoResult(info: "", error: "No session, please start \(tab.rawValue) flow to authenticate.", isLoading: false)
        }
        
        let userInfo = await user.userinfo(cache: false)
        switch userInfo {
        case .success(let userInfoDictionary):
            var description = ""
            userInfoDictionary.forEach { description += "\($0): \($1)\n" }
            LogManager.standard.i("\(tab.rawValue) UserInfo: \(description)")
            return UserInfoResult(info: description, isLoading: false)
        case .failure(let error):
            LogManager.standard.e("", error: error)
            return UserInfoResult(info: "", error: error.localizedDescription, isLoading: false)
        }
    }
}
