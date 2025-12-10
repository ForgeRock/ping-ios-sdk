//
//  DefaultNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and timestamp
            HStack {
                Image(systemName: "hand.tap.fill")
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
                    Text("Authentication Request")
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

            // Message
            if let message = notification.messageText {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
            }

            // Action buttons
            if !notification.isExpired {
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
                        Task {
                            await viewModel.approveNotification(id: notification.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
