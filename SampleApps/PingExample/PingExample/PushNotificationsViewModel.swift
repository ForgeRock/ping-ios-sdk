//
//  PushNotificationsViewModel.swift
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

/// ViewModel for managing push notifications.
/// Handles loading, approving, and denying notifications.
@MainActor
class PushNotificationsViewModel: ObservableObject {
    @Published var pendingNotifications: [PushNotification] = []
    @Published var allNotifications: [PushNotification] = []
    @Published var credentials: [PushCredential] = []
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

    func loadNotifications() async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            credentials = try await client.getCredentials()
            pendingNotifications = try await client.getPendingNotifications()
            allNotifications = try await client.getAllNotifications()
        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func credential(for notification: PushNotification) -> PushCredential? {
        credentials.first { $0.id == notification.credentialId }
    }

    func approveNotification(id: String) async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await client.approveNotification(id)
            await loadNotifications()
        } catch {
            errorMessage = "Failed to approve notification: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func denyNotification(id: String) async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await client.denyNotification(id)
            await loadNotifications()
        } catch {
            errorMessage = "Failed to deny notification: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func approveChallengeNotification(id: String, challengeResponse: String) async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await client.approveChallengeNotification(id, challengeResponse: challengeResponse)
            await loadNotifications()
        } catch {
            errorMessage = "Failed to approve challenge: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func approveBiometricNotification(id: String) async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await client.approveBiometricNotification(id, authenticationMethod: "biometric")
            await loadNotifications()
        } catch {
            errorMessage = "Failed to approve biometric: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
