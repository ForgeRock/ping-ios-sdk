//
//  PushAccountsViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingPush

/// ViewModel to manage push accounts.
/// Handles loading, deleting accounts and device token retrieval.
@MainActor
class PushAccountsViewModel: ObservableObject {
    @Published var accounts: [PushCredential] = []
    @Published var deviceToken: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func initialize() async {
        guard ConfigurationManager.shared.pushClient == nil else { return }

        isLoading = true
        do {
            try await ConfigurationManager.shared.initializePushClient()
        } catch {
            errorMessage = "Failed to initialize Push client: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadAccounts() async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
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

    func loadDeviceToken() async {
        guard let client = ConfigurationManager.shared.pushClient else {
            return
        }

        do {
            deviceToken = try await client.getDeviceToken()
        } catch {
            // Device token not set yet, this is normal
            deviceToken = nil
        }
    }

    func deleteAccount(id: String) async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let deleted = try await client.deleteCredential(credentialId: id)
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
