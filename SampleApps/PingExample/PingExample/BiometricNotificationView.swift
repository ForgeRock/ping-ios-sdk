//
//  BiometricNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush
import LocalAuthentication

/// A SwiftUI view to display a biometric authentication push notification
/// and allow the user to approve or deny it using biometrics.
struct BiometricNotificationView: View {
    let notification: PushNotification
    @ObservedObject var viewModel: PushNotificationsViewModel
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            // Header with icon and timestamp
            HStack {
                PingIconTile(systemName: "faceid", diameter: 40, iconSize: 20)

                VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                    Text("Biometric Authentication")
                        .pingSectionHeader()

                    Text(notification.createdAt, style: .relative)
                        .pingSupportingText()
                }

                Spacer()

                if notification.isExpired {
                    Label("Expired", systemImage: "clock.badge.exclamationmark")
                        .font(PingTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(PingTheme.Color.statusWarning)
                }
            }

            // Credential info
            if let credential = viewModel.credential(for: notification) {
                HStack(spacing: PingTheme.Spacing.xSmall) {
                    Text(credential.displayIssuer)
                        .font(PingTheme.Typography.body.weight(.medium))
                        .foregroundStyle(PingTheme.Color.contentPrimary)
                    Text("•")
                        .foregroundStyle(PingTheme.Color.contentSecondary)
                    Text(credential.displayAccountName)
                        .pingBodySecondary()
                }
            }

            // Message
            if let message = notification.messageText {
                Text(message)
                    .font(PingTheme.Typography.supporting)
                    .foregroundStyle(PingTheme.Color.contentPrimary)
                    .padding(.vertical, PingTheme.Spacing.small)
            }

            // Biometric prompt
            if !notification.isExpired {
                VStack(spacing: PingTheme.Spacing.medium) {
                    Text("Use biometric authentication to approve this request")
                        .pingSupportingText()
                        .multilineTextAlignment(.center)

                    HStack(spacing: PingTheme.Spacing.medium) {
                        Button(action: {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Deny")
                            }
                        }
                        .buttonStyle(.pingDestructive)

                        Button(action: {
                            authenticateWithBiometrics()
                        }) {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Authenticate")
                            }
                        }
                        .buttonStyle(.pingAffirmative)
                    }
                }
            }
        }
        .pingCardStyle()
        .pingErrorAlert(errorMessage: $errorMessage)
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to approve this push notification"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                Task { @MainActor in
                    if success {
                        await viewModel.approveBiometricNotification(id: notification.id)
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
        }
    }
}
