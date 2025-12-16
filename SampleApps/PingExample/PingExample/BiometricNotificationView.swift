//
//  BiometricNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and timestamp
            HStack {
                Image(systemName: "faceid")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Biometric Authentication")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(notification.createdAt, style: .relative)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if notification.isExpired {
                    Label("Expired", systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }

            // Credential info
            if let credential = viewModel.credential(for: notification) {
                HStack(spacing: 4) {
                    Text(credential.displayIssuer)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(credential.displayAccountName)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }

            // Message
            if let message = notification.messageText {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
            }

            // Biometric prompt
            if !notification.isExpired {
                VStack(spacing: 12) {
                    Text("Use biometric authentication to approve this request")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Deny")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button(action: {
                            authenticateWithBiometrics()
                        }) {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Authenticate")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert("Authentication Failed", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
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
                        showError = true
                    }
                }
            }
        } else {
            errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            showError = true
        }
    }
}
