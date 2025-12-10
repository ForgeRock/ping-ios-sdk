//
//  OathAccountsViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOath

/// ViewModel to manage OATH accounts.
/// Handles loading, deleting, and error states.
@MainActor
class OathAccountsViewModel: ObservableObject {
    @Published var accounts: [OathCredential] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func initialize() async {
        guard ConfigurationManager.shared.oathClient == nil else { return }

        isLoading = true
        do {
            try await ConfigurationManager.shared.initializeOathClient()
        } catch {
            errorMessage = "Failed to initialize OATH client: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadAccounts() async {
        guard let client = ConfigurationManager.shared.oathClient else {
            // Client not initialized yet, silently return
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            accounts = try await client.getCredentials()
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteAccount(id: String) async {
        guard let client = ConfigurationManager.shared.oathClient else {
            errorMessage = "OATH client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let deleted = try await client.deleteCredential(id)
            if deleted {
                accounts.removeAll { $0.id == id }
            } else {
                errorMessage = "Failed to delete account"
            }
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
