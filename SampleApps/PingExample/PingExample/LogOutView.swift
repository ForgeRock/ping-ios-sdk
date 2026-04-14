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
            ScrollView {
                VStack(spacing: 16) {
                    if logoutViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if logoutViewModel.activeSessions.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.shield.fill",
                            title: "No Active Sessions"
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 200)
                    } else {
                        Text("You have \(logoutViewModel.activeSessions.count) active \(logoutViewModel.activeSessions.count == 1 ? "session" : "sessions")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        ForEach(logoutViewModel.activeSessions) { session in
                            sessionCard(session)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 16)
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeButtonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Logout")
    }
    
    private func sessionCard(_ session: SessionInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: session.tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.themeButtonBackground)
                    .frame(width: 36, height: 36)
                    .background(Color.themeButtonBackground.opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(session.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Button {
                Task {
                    await logoutViewModel.logout(session: session)
                }
            } label: {
                Text("Log Out")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.themeButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
