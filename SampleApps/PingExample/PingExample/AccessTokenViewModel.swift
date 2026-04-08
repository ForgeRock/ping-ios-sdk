//
//  AccessTokenViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOidc

struct AccessTokenResult {
    var info: String = ""
    var error: String? = nil
    var isLoading: Bool = true
}

@MainActor
class AccessTokenViewModel: ObservableObject {
    @Published var results: [UserInfoTab: AccessTokenResult] = [
        .journey: AccessTokenResult(),
        .davinci: AccessTokenResult(),
        .oidc: AccessTokenResult()
    ]
    
    init() {
        Task {
            await fetchAllTokens()
        }
    }
    
    func fetchAllTokens() async {
        await withTaskGroup(of: (UserInfoTab, AccessTokenResult).self) { group in
            group.addTask { await (.journey, self.fetchToken(for: .journey)) }
            group.addTask { await (.davinci, self.fetchToken(for: .davinci)) }
            group.addTask { await (.oidc, self.fetchToken(for: .oidc)) }
            
            for await (tab, result) in group {
                results[tab] = result
            }
        }
    }
    
    private func fetchToken(for tab: UserInfoTab) async -> AccessTokenResult {
        let user: User?
        switch tab {
        case .journey:
            user = await ConfigurationManager.shared.journeyUser
        case .davinci:
            user = await ConfigurationManager.shared.davinciUser
        case .oidc:
            user = await ConfigurationManager.shared.oidcUser
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
}
