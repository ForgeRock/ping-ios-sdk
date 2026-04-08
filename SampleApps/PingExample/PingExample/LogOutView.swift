// 
//  LogOutView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

struct LogOutView: View {
    @Binding var path: [MenuItem]
    @StateObject private var logoutViewModel = LogOutViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Active Sessions")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select a session to logout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if logoutViewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if logoutViewModel.activeSessions.isEmpty {
                    Text("No active sessions")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                } else {
                    NextButton(title: "Logout All Sessions") {
                        Task {
                            await logoutViewModel.logoutAll()
                        }
                    }
                    
                    ForEach(logoutViewModel.activeSessions) { session in
                        sessionCard(session)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Logout")
    }
    
    private func sessionCard(_ session: SessionInfo) -> some View {
        VStack(spacing: 12) {
            Text(session.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(session.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            NextButton(title: "Logout from \(session.tab.rawValue) Session") {
                Task {
                    await logoutViewModel.logout(session: session)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
