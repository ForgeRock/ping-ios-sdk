//
//  PushNotificationsView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
            .background(Color(.systemGroupedBackground))

            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var pendingTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.pendingNotifications.isEmpty {
                    emptyPendingView
                } else {
                    ForEach(viewModel.pendingNotifications, id: \.id) { notification in
                        PushNotificationCardView(
                            notification: notification,
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private var historyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.allNotifications.isEmpty {
                    emptyHistoryView
                } else {
                    ForEach(viewModel.allNotifications, id: \.id) { notification in
                        Button {
                            selectedNotification = notification
                        } label: {
                            NotificationHistoryCard(notification: notification, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private var emptyPendingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()

            Text("No Pending Notifications")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("You're all caught up! New push authentication requests will appear here.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()

            Text("No History")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("Your notification history will appear here after you respond to push requests.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
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
            return ("checkmark.circle.fill", .green, "Approved")
        } else if notification.isExpired && notification.pending {
            return ("clock.badge.exclamationmark.fill", .orange, "Expired")
        } else if notification.pending {
            return ("clock.fill", .blue, "Pending")
        } else {
            return ("xmark.circle.fill", .red, "Denied")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusInfo.icon)
                    .foregroundColor(statusInfo.color)
                    .font(.system(size: 20))

                Text(statusInfo.text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(notification.respondedAt ?? notification.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Credential info
            if let credential = viewModel.credential(for: notification) {
                HStack(spacing: 4) {
                    Text(credential.displayIssuer)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(credential.displayAccountName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            if let message = notification.messageText {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Label(notification.pushType.rawValue.uppercased(), systemImage: typeIcon(notification.pushType))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
