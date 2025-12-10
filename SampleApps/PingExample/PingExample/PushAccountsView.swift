//
//  PushAccountsView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    deviceTokenSection

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
        .navigationTitle("Push Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.qrScanner)
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .task {
            await viewModel.initialize()
            await viewModel.loadAccounts()
            await viewModel.loadDeviceToken()
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

    private var deviceTokenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "smartphone")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.themeButtonBackground)

                Text("Device Token")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: viewModel.deviceToken != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(viewModel.deviceToken != nil ? .green : .orange)
            }

            if let token = viewModel.deviceToken {
                Text(token)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                Text("No device token registered")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()

            Text("No Push Accounts")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("Scan a QR code to register your first push authentication account")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                path.append(.qrScanner)
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
                PushAccountCardView(credential: account)
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
