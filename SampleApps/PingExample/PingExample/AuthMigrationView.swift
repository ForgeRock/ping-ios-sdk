//
//  AuthMigrationView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// A view that allows developers to test migration of legacy FRAuthenticator credentials
/// (OATH and Push) to the modern Ping SDK storage format.
struct AuthMigrationView: View {
    @StateObject private var viewModel = AuthMigrationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                instructionsCard
                migrationStatusCard
                if !viewModel.stepResults.isEmpty {
                    progressCard
                }
                if let summary = viewModel.summaryMessage {
                    resultCard(message: summary, isError: false)
                }
                if let error = viewModel.errorMessage {
                    resultCard(message: error, isError: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Migration")
        .task {
            await viewModel.checkMigrationNeeded()
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to Test", systemImage: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.themeButtonBackground)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: "Install a legacy FRAuthenticator app using the same bundle identifier as PingExample.")
                instructionRow(number: "2", text: "Register OATH (TOTP/HOTP) and/or Push accounts in the legacy app.")
                instructionRow(number: "3", text: "Delete the legacy app from the device.")
                instructionRow(number: "4", text: "Install PingExample (same bundle identifier ensures Keychain data persists).")
                instructionRow(number: "5", text: "Open this screen and tap \"Start Migration\" to import the legacy credentials.")
            }

            Text("Note: Only one app with the same bundle identifier can be installed at a time. Keychain data persists across app installs/uninstalls as long as the bundle identifier matches.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.themeButtonBackground)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Migration Status Card

    private var migrationStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Legacy Data", systemImage: "externaldrive.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                migrationStatusBadge
            }

            Divider()

            startMigrationButton
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var migrationStatusBadge: some View {
        switch viewModel.migrationStatus {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Checking...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        case .idle:
            if let needed = viewModel.isMigrationNeeded {
                if needed {
                    Text("Found")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("None")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                EmptyView()
            }
        case .running:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Migrating...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
        case .completed:
            Text("Completed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        case .failed:
            Text("Failed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var startMigrationButton: some View {
        Button {
            Task {
                await viewModel.startMigration()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Start Migration")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonDisabled ? Color.gray : Color.themeButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(buttonDisabled)
    }

    private var buttonDisabled: Bool {
        viewModel.migrationStatus == .running
        || viewModel.migrationStatus == .completed
        || viewModel.migrationStatus == .checking
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress", systemImage: "list.bullet.clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Divider()

            ForEach(viewModel.stepResults) { step in
                HStack(spacing: 12) {
                    stepStatusIcon(step.status)

                    Text(step.stepDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: MigrationStepResult.StepStatus) -> some View {
        switch status {
        case .inProgress:
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 20, height: 20)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 20, height: 20)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Result Card

    private func resultCard(message: String, isError: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(isError ? .red : .green)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(16)
        .background(
            (isError ? Color.red : Color.green)
                .opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
