//
//  PushAccountsView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// View to display and manage push authentication accounts.
/// Allows users to view their device token, list of registered push accounts, and add new accounts.
struct PushAccountsView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PushAccountsViewModel()
    @State private var selectedAccount: PushCredential?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                deviceTokenSection
                    .pingScrollContentPadding(bottom: 0)

                if viewModel.isLoading && viewModel.accounts.isEmpty {
                    ScrollView {
                        VStack(spacing: PingTheme.Spacing.large) {
                            PingLoadingSpinner()
                                .padding()
                        }
                        .pingScrollContentPadding(top: PingTheme.Spacing.large)
                    }
                } else if viewModel.accounts.isEmpty {
                    PingCenteredScrollContent { emptyStateView }
                } else {
                    ScrollView {
                        VStack(spacing: PingTheme.Spacing.large) {
                            accountsList
                        }
                        .pingScrollContentPadding(top: PingTheme.Spacing.large)
                    }
                }
            }
            .pingScreenBackground()

            if viewModel.isLoading && !viewModel.accounts.isEmpty {
                PingLoadingOverlay()
            }
        }
        .navigationTitle("Push Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.qrScanner)
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .accessibilityLabel("Scan QR Code")
            }
        }
        .task {
            await viewModel.initialize()
            await viewModel.loadAccounts()
            await viewModel.loadDeviceToken()
        }
        .sheet(item: $selectedAccount, onDismiss: {
            Task {
                await viewModel.loadAccounts()
            }
        }) { account in
            NavigationStack {
                PushAccountDetailView(credential: account)
            }
        }
        .onAppear {
            // Reload accounts and token when view appears (e.g., after returning from QR scanner)
            Task {
                await viewModel.loadAccounts()
                await viewModel.loadDeviceToken()
            }
        }
        .refreshable {
            await viewModel.loadAccounts()
            await viewModel.loadDeviceToken()
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    private var deviceTokenSection: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.large) {
            HStack {
                Image(systemName: "smartphone")
                    .font(PingTheme.Typography.sectionTitle)
                    .foregroundColor(PingTheme.Color.actionPrimary)

                Text("Device Token")
                    .pingSectionHeader()

                Spacer()

                Image(systemName: viewModel.deviceToken != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(viewModel.deviceToken != nil ? PingTheme.Color.statusSuccess : PingTheme.Color.statusWarning)
            }

            if let token = viewModel.deviceToken {
                Text(token)
                    .font(PingTheme.Typography.monospacedCaption)
                    .foregroundStyle(PingTheme.Color.contentSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                Text("No device token registered")
                    .pingSupportingText()
            }
        }
        .pingCardStyle()
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "bell.badge.fill",
            title: "No Push Accounts",
            subtitle: "Scan a QR code to register your first push authentication account"
        ) {
            Button {
                path.append(.qrScanner)
            } label: {
                VStack(spacing: PingTheme.Spacing.small) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(PingTheme.Typography.screenTitle)
                    Text("Scan QR Code")
                        .font(PingTheme.Typography.supporting.weight(.medium))
                }
                .frame(width: 140, height: 100)
                .background(PingTheme.Color.groupedSurface)
                .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
            }
            .buttonStyle(.plain)
            .padding(.top, PingTheme.Spacing.large)
        }
    }

    private var accountsList: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            ForEach(viewModel.accounts, id: \.id) { account in
                PushAccountCardView(credential: account) {
                    selectedAccount = account
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteAccount(id: account.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}
