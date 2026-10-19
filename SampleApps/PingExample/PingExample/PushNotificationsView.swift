//
//  PushNotificationsView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// View to display and manage push notifications.
/// Allows users to view their pending and historical push notifications.
struct PushNotificationsView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PushNotificationsViewModel()
    @State private var selectedTab = 0
    @State private var selectedNotification: PushNotification?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Pending").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    pendingTab
                        .tag(0)

                    historyTab
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .pingScreenBackground()

            if viewModel.isLoading {
                PingLoadingOverlay()
            }
        }
        .navigationTitle("Push Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.initialize()
            await viewModel.loadNotifications()
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
        .sheet(item: $selectedNotification) { notification in
            NavigationStack {
                PushNotificationDetailView(
                    notification: notification,
                    credential: viewModel.credential(for: notification)
                )
            }
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    @ViewBuilder
    private var pendingTab: some View {
        if viewModel.pendingNotifications.isEmpty {
            PingCenteredScrollContent { emptyPendingView }
        } else {
            ScrollView {
                VStack(spacing: PingTheme.Spacing.medium) {
                    ForEach(viewModel.pendingNotifications, id: \.id) { notification in
                        PushNotificationCardView(
                            notification: notification,
                            viewModel: viewModel
                        )
                    }
                }
                .pingScrollContentPadding()
            }
        }
    }

    @ViewBuilder
    private var historyTab: some View {
        if viewModel.allNotifications.isEmpty {
            PingCenteredScrollContent { emptyHistoryView }
        } else {
            ScrollView {
                VStack(spacing: PingTheme.Spacing.medium) {
                    ForEach(viewModel.allNotifications, id: \.id) { notification in
                        Button {
                            selectedNotification = notification
                        } label: {
                            NotificationHistoryCard(notification: notification, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .pingScrollContentPadding()
            }
        }
    }

    private var emptyPendingView: some View {
        EmptyStateView(
            icon: "bell.slash.fill",
            title: "No Pending Notifications",
            subtitle: "You're all caught up! New push authentication requests will appear here."
        )
    }

    private var emptyHistoryView: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No History",
            subtitle: "Your notification history will appear here after you respond to push requests."
        )
    }
}

struct NotificationHistoryCard: View {
    let notification: PushNotification
    let viewModel: PushNotificationsViewModel
    
    // Determine status following Android logic:
    // 1. approved -> APPROVED
    // 2. expired && pending -> EXPIRED
    // 3. pending -> PENDING
    // 4. else -> DENIED
    private var statusInfo: (icon: String, color: Color, text: String) {
        if notification.approved {
            return ("checkmark.circle.fill", PingTheme.Color.statusSuccess, "Approved")
        } else if notification.isExpired && notification.pending {
            return ("clock.badge.exclamationmark.fill", PingTheme.Color.statusWarning, "Expired")
        } else if notification.pending {
            return ("clock.fill", PingTheme.Color.statusInfo, "Pending")
        } else {
            return ("xmark.circle.fill", PingTheme.Color.statusError, "Denied")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            HStack {
                Image(systemName: statusInfo.icon)
                    .foregroundStyle(statusInfo.color)
                    .font(PingTheme.Typography.sectionTitle)

                Text(statusInfo.text)
                    .font(PingTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(PingTheme.Color.contentPrimary)

                Spacer()

                Text(notification.respondedAt ?? notification.createdAt, style: .relative)
                    .pingSupportingText()
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

            if let message = notification.messageText {
                Text(message)
                    .pingSupportingText()
                    .lineLimit(2)
            }

            HStack {
                Label(notification.pushType.rawValue.uppercased(), systemImage: typeIcon(notification.pushType))
                    .font(PingTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(PingTheme.Color.contentSecondary)

                Spacer()
            }
        }
        .pingCardStyle()
    }

    private func typeIcon(_ type: PushType) -> String {
        switch type {
        case .default: return "hand.tap.fill"
        case .biometric: return "faceid"
        case .challenge: return "number.circle.fill"
        @unknown default: return "hand.tap.fill"
        }
    }
}
