//
//  PingOneMFAAccountsViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOneMFA

/// ViewModel to manage PingOne MFA accounts.
/// Handles lazy SDK initialization, account loading, and error states.
@MainActor
class PingOneMFAAccountsViewModel: ObservableObject {
    @Published var accounts: [PingOneMfaAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func initialize() async {
        guard !ConfigurationManager.shared.isPingOneMFAInitialized else { return }

        isLoading = true
        do {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
        } catch {
            errorMessage = "Failed to initialize PingOne MFA: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadAccounts() async {
        guard ConfigurationManager.shared.isPingOneMFAInitialized else {
            // SDK not initialized — silently return so the initialization error
            // surfaced by `initialize()` remains visible to the user.
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await PingOneMFA.getDeviceInfo()
            accounts = result.accounts
            if let errors = result.errors, !errors.isEmpty {
                errorMessage = "Failed to load accounts: " + errors.map { $0.localizedDescription }.joined(separator: "; ")
            }
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
