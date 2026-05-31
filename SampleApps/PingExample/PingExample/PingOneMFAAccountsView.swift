//
//  PingOneMFAAccountsView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOneMFA

/// View to display and manage paired PingOne MFA accounts.
/// Shows each account's name and environment in a styled card.
struct PingOneMFAAccountsView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PingOneMFAAccountsViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.accounts.isEmpty {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else if viewModel.accounts.isEmpty {
                        emptyStateView
                    } else {
                        accountsList
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }

            if viewModel.isLoading && !viewModel.accounts.isEmpty {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .navigationTitle("MFA Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.pingOneMFAScanner)
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .task {
            await viewModel.initialize()
            await viewModel.loadAccounts()
        }
        .refreshable {
            await viewModel.loadAccounts()
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

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No MFA Accounts",
            subtitle: "Scan a QR code to pair your first PingOne MFA account"
        ) {
            Button {
                path.append(.pingOneMFAScanner)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                    Text("Scan QR Code")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(width: 140, height: 100)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 20)
        }
        .padding()
    }

    private var accountsList: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.accounts, id: \.id) { account in
                PingOneMFAAccountCardView(account: account)
            }
        }
    }
}

// MARK: - Account Card View

/// Inline card row for a single PingOneMfaAccount.
/// Displays the user ID (primary label), environment ID, and region.
private struct PingOneMFAAccountCardView: View {
    let account: PingOneMfaAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
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
                    Text("\(account.name) \(account.family)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Region: \(account.region)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("ID: \(account.id)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
