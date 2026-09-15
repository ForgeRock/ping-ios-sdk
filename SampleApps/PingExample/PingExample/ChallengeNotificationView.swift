//
//  ChallengeNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// A SwiftUI view representing a challenge authentication push notification
/// that allows the user to select a challenge number to approve the authentication.
struct ChallengeNotificationView: View {
    let notification: PushNotification
    @ObservedObject var viewModel: PushNotificationsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: PingTheme.Spacing.medium) {
            // Header with icon and timestamp
            HStack {
                PingIconTile(systemName: "number.circle.fill", diameter: 40, iconSize: 20)

                VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                    Text("Challenge Authentication")
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Message
            if let message = notification.messageText {
                Text(message)
                    .font(PingTheme.Typography.supporting)
                    .foregroundStyle(PingTheme.Color.contentPrimary)
                    .padding(.vertical, PingTheme.Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Challenge selection UI
            if !notification.isExpired {
                let challengeNumbers = notification.getNumbersChallenge()

                VStack(spacing: PingTheme.Spacing.large) {
                    Text("Select the number shown on your other device")
                        .pingBodySecondary()
                        .multilineTextAlignment(.center)

                    if !challengeNumbers.isEmpty {
                        HStack(spacing: PingTheme.Spacing.medium) {
                            ForEach(challengeNumbers, id: \.self) { number in
                                PingChallengeNumberButton(number: number) {
                                    Task {
                                        await viewModel.approveChallengeNotification(
                                            id: notification.id,
                                            challengeResponse: String(number)
                                        )
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: PingTheme.Spacing.small)

                        Button {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        } label: {
                            Text("Cancel Authentication")
                        }
                        .buttonStyle(.pingDestructive)
                    } else {
                        Text("No challenge numbers available")
                            .font(PingTheme.Typography.body)
                            .foregroundStyle(PingTheme.Color.statusError)

                        Spacer().frame(height: PingTheme.Spacing.medium)

                        Button {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        } label: {
                            Text("Close")
                        }
                        .buttonStyle(.pingDestructive)
                    }
                }
            }
        }
        .pingCardStyle()
    }
}
