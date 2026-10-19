//
//  PingOneMFAAccountsView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
            if viewModel.isLoading && viewModel.accounts.isEmpty {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        PingLoadingSpinner()
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .pingScrollContentPadding()
                }
            } else if viewModel.accounts.isEmpty {
                PingCenteredScrollContent { emptyStateView }
            } else {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        accountsList
                    }
                    .frame(maxWidth: .infinity)
                    .pingScrollContentPadding()
                }
            }

            if viewModel.isLoading && !viewModel.accounts.isEmpty {
                PingLoadingOverlay()
            }
        }
        .pingScreenBackground()
        .navigationTitle("MFA Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.pingOneMFAScanner)
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .accessibilityLabel("Scan QR Code")
            }
        }
        .task {
            await viewModel.initialize()
            await viewModel.loadAccounts()
        }
        .refreshable {
            await viewModel.loadAccounts()
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
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
        HStack(spacing: PingTheme.Spacing.medium) {
            PingIconTile(systemName: "person.2.fill", diameter: 40, iconSize: 20)

            VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                Text("\(account.name) \(account.family)")
                    .font(PingTheme.Typography.supporting.weight(.semibold))
                    .foregroundStyle(PingTheme.Color.contentPrimary)

                Text("Region: \(account.region)")
                    .pingCaptionText()

                Text("ID: \(account.id)")
                    .font(PingTheme.Typography.caption)
                    .foregroundStyle(PingTheme.Color.contentTertiary)
            }
        }
        .pingCardStyle()
    }
}
