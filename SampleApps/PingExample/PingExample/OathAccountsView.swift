//
//  OathAccountsView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOath

/// View to display and manage OATH accounts.
/// Allows adding accounts via QR code or manual entry, viewing details, and deleting accounts.
struct OathAccountsView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = OathAccountsViewModel()
    @State private var showManualRegistration = false
    @State private var selectedAccount: OathCredential?

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.accounts.isEmpty {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        PingLoadingSpinner()
                            .padding()
                    }
                    .pingScrollContentPadding()
                }
            } else if viewModel.accounts.isEmpty {
                PingCenteredScrollContent { emptyStateView }
            } else {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        accountsList
                    }
                    .pingScrollContentPadding()
                }
            }
            if viewModel.isLoading && !viewModel.accounts.isEmpty {
                PingLoadingOverlay()
            }
        }
        .pingScreenBackground()
        .navigationTitle("OATH Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        path.append(.qrScanner)
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }

                    Button {
                        showManualRegistration = true
                    } label: {
                        Label("Manual Entry", systemImage: "keyboard")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showManualRegistration) {
            NavigationStack {
                ManualOathRegistrationView(isPresented: $showManualRegistration)
            }
        }
        .onChange(of: showManualRegistration) { isPresented in
            if !isPresented {
                // Sheet was dismissed, reload accounts
                Task {
                    await viewModel.loadAccounts()
                }
            }
        }
        .sheet(item: $selectedAccount, onDismiss: {
            Task {
                await viewModel.loadAccounts()
            }
        }) { account in
            NavigationStack {
                OathAccountDetailView(credential: account)
            }
        }
        .task {
            await viewModel.initialize()
            await viewModel.loadAccounts()
        }
        .refreshable {
            await viewModel.loadAccounts()
        }
        .onDisappear {
            // Stop tracking when view disappears
            Task { @MainActor in
                ConfigurationManager.shared.oathTimerService?.stopTracking()
            }
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "key.viewfinder",
            title: "No OATH Accounts",
            subtitle: "Add your first account using QR code or manual entry"
        ) {
            HStack(spacing: PingTheme.Spacing.medium) {
                Button {
                    path.append(.qrScanner)
                } label: {
                    VStack(spacing: PingTheme.Spacing.small) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(PingTheme.Typography.screenTitle)
                        Text("Scan QR")
                            .font(PingTheme.Typography.supporting.weight(.medium))
                    }
                    .frame(width: 120, height: 100)
                    .background(PingTheme.Color.groupedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
                }
                .buttonStyle(.plain)

                Button {
                    showManualRegistration = true
                } label: {
                    VStack(spacing: PingTheme.Spacing.small) {
                        Image(systemName: "keyboard")
                            .font(PingTheme.Typography.screenTitle)
                        Text("Manual Entry")
                            .font(PingTheme.Typography.supporting.weight(.medium))
                    }
                    .frame(width: 120, height: 100)
                    .background(PingTheme.Color.groupedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, PingTheme.Spacing.large)
        }
    }

    private var accountsList: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            ForEach(viewModel.accounts, id: \.id) { account in
                if let timerService = ConfigurationManager.shared.oathTimerService {
                    OathAccountCardView(credential: account, timerService: timerService) {
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
}
