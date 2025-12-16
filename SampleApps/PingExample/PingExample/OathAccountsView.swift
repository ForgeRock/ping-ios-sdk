//
//  OathAccountsView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
    @State private var showError = false

    var body: some View {
        ZStack {
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.isLoading && !viewModel.accounts.isEmpty {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
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
        .onChange(of: viewModel.errorMessage) { newError in
            showError = newError != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.errorMessage = nil
                showError = false
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()

            Text("No OATH Accounts")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("Add your first account using QR code or manual entry")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button {
                    path.append(.qrScanner)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 24))
                        Text("Scan QR")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 120, height: 100)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    showManualRegistration = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 24))
                        Text("Manual Entry")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 120, height: 100)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding()
    }

    private var accountsList: some View {
        VStack(spacing: 16) {
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
