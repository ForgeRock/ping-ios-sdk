//
//  LogOutView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// Displays active authentication sessions and provides per-session and bulk logout actions.
/// Shows a "No Active Sessions" placeholder when all sessions are cleared.
struct LogOutView: View {
    @Binding var path: [MenuItem]
    @StateObject private var logoutViewModel = LogOutViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if logoutViewModel.isLoading {
                PingCenteredScrollContent {
                    PingLoadingSpinner()
                }
            } else if logoutViewModel.activeSessions.isEmpty {
                PingCenteredScrollContent {
                    EmptyStateView(
                        icon: "checkmark.shield.fill",
                        title: "No Active Sessions"
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.medium) {
                        Text("You have \(logoutViewModel.activeSessions.count) active \(logoutViewModel.activeSessions.count == 1 ? "session" : "sessions")")
                            .pingSupportingText()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, PingTheme.Spacing.screen)

                        ForEach(logoutViewModel.activeSessions) { session in
                            sessionCard(session)
                                .padding(.horizontal, PingTheme.Spacing.screen)
                        }
                    }
                    .padding(.top, PingTheme.Spacing.medium)
                }
            }

            if !logoutViewModel.isLoading && logoutViewModel.activeSessions.count > 0 {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        Task {
                            await logoutViewModel.logoutAll()
                        }
                    } label: {
                        Text("Log Out of All Sessions")
                    }
                    .buttonStyle(.pingDestructive)
                    .padding(.horizontal, PingTheme.Spacing.screen)
                    .padding(.vertical, PingTheme.Spacing.medium)
                }
                .background(PingTheme.Color.appBackground)
            }
        }
        .pingScreenBackground()
        .navigationTitle("Logout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionCard(_ session: SessionInfo) -> some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            HStack(spacing: PingTheme.Spacing.medium) {
                Image(systemName: session.tab.icon)
                    .foregroundStyle(PingTheme.Color.actionPrimary)
                    .frame(width: 36, height: 36)
                    .background(PingTheme.Color.actionPrimary.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                    Text(session.title)
                        .pingSectionHeader()
                    Text(session.description)
                        .pingSupportingText()
                }
                Spacer()
            }

            Button {
                Task {
                    await logoutViewModel.logout(session: session)
                }
            } label: {
                Text("Log Out")
            }
            .buttonStyle(.pingDestructive)
        }
        .pingCardStyle()
    }
}
