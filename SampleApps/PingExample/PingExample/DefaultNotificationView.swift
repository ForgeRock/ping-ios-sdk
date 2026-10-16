//
//  DefaultNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// A SwiftUI view that displays a default push notification with approve and deny actions.
struct DefaultNotificationView: View {
    let notification: PushNotification
    @ObservedObject var viewModel: PushNotificationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            // Header with icon and timestamp
            HStack {
                PingIconTile(systemName: "hand.tap.fill", diameter: 40, iconSize: 20)

                VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                    Text("Authentication Request")
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

            // Action buttons
            if !notification.isExpired {
                HStack(spacing: PingTheme.Spacing.medium) {
                    Button {
                        Task {
                            await viewModel.denyNotification(id: notification.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Deny")
                        }
                    }
                    .buttonStyle(.pingDestructive)

                    Button {
                        Task {
                            await viewModel.approveNotification(id: notification.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                    }
                    .buttonStyle(.pingAffirmative)
                }
            }
        }
        .pingCardStyle()
    }
}
