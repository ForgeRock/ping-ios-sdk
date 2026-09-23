//
//  AuthMigrationView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: PingTheme.Spacing.large) {
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
            .padding(.horizontal, PingTheme.Spacing.screen)
            .padding(.vertical, PingTheme.Spacing.medium)
        }
        .pingScreenBackground()
        .navigationTitle("Migration")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.checkMigrationNeeded()
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Label("How to Test", systemImage: "info.circle.fill")
                .font(PingTheme.Typography.sectionTitle)
                .foregroundStyle(PingTheme.Color.actionPrimary)

            Divider()

            VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                instructionRow(number: 1, text: "Install a legacy FRAuthenticator app using the same bundle identifier as PingExample.")
                instructionRow(number: 2, text: "Register OATH (TOTP/HOTP) and/or Push accounts in the legacy app.")
                instructionRow(number: 3, text: "Delete the legacy app from the device.")
                instructionRow(number: 4, text: "Install PingExample (same bundle identifier ensures Keychain data persists).")
                instructionRow(number: 5, text: "Open this screen and tap \"Start Migration\" to import the legacy credentials.")
            }

            Text("Note: Only one app with the same bundle identifier can be installed at a time. Keychain data persists across app installs/uninstalls as long as the bundle identifier matches.")
                .pingCaptionText()
                .padding(.top, PingTheme.Spacing.xSmall)
        }
        .pingCardStyle()
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: PingTheme.Spacing.small) {
            PingStepBadge(number: number)

            Text(text)
                .font(PingTheme.Typography.supporting)
                .foregroundStyle(PingTheme.Color.contentPrimary)
        }
    }

    // MARK: - Migration Status Card

    private var migrationStatusCard: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            HStack {
                Label("Legacy Data", systemImage: "externaldrive.fill")
                    .pingSectionHeader()

                Spacer()

                migrationStatusBadge
            }

            Divider()

            startMigrationButton
        }
        .pingCardStyle()
    }

    @ViewBuilder
    private var migrationStatusBadge: some View {
        switch viewModel.migrationStatus {
        case .checking:
            HStack(spacing: PingTheme.Spacing.xSmall) {
                PingLoadingSpinner()
                    .scaleEffect(0.7)
                Text("Checking...")
                    .pingCaptionText()
            }
        case .idle:
            if let needed = viewModel.isMigrationNeeded {
                if needed {
                    statusBadge(text: "Found", color: PingTheme.Color.statusWarning)
                } else {
                    statusBadge(text: "None", color: PingTheme.Color.contentSecondary)
                }
            } else {
                EmptyView()
            }
        case .running:
            HStack(spacing: PingTheme.Spacing.xSmall) {
                PingLoadingSpinner()
                    .scaleEffect(0.7)
                Text("Migrating...")
                    .font(PingTheme.Typography.caption)
                    .foregroundStyle(PingTheme.Color.statusInfo)
            }
        case .completed:
            statusBadge(text: "Completed", color: PingTheme.Color.statusSuccess)
        case .failed:
            statusBadge(text: "Failed", color: PingTheme.Color.statusError)
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(PingTheme.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, PingTheme.Spacing.small)
            .padding(.vertical, PingTheme.Spacing.xSmall)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
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
            }
        }
        .buttonStyle(.pingPrimary)
        .disabled(buttonDisabled)
    }

    private var buttonDisabled: Bool {
        viewModel.migrationStatus == .running
        || viewModel.migrationStatus == .completed
        || viewModel.migrationStatus == .checking
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Label("Progress", systemImage: "list.bullet.clipboard")
                .pingSectionHeader()

            Divider()

            ForEach(viewModel.stepResults) { step in
                HStack(spacing: PingTheme.Spacing.small) {
                    stepStatusIcon(step.status)

                    Text(step.stepDescription)
                        .font(PingTheme.Typography.supporting)
                        .foregroundStyle(PingTheme.Color.contentPrimary)

                    Spacer()
                }
                .padding(.vertical, PingTheme.Spacing.xSmall)
            }
        }
        .pingCardStyle()
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: MigrationStepResult.StepStatus) -> some View {
        switch status {
        case .inProgress:
            PingLoadingSpinner()
                .scaleEffect(0.8)
                .frame(width: 20, height: 20)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PingTheme.Color.statusSuccess)
                .frame(width: 20, height: 20)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PingTheme.Color.statusError)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Result Card

    private func resultCard(message: String, isError: Bool) -> some View {
        HStack(spacing: PingTheme.Spacing.small) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: PingTheme.Control.Glyph.medium))
                .foregroundStyle(isError ? PingTheme.Color.statusError : PingTheme.Color.statusSuccess)

            Text(message)
                .font(PingTheme.Typography.supporting)
                .foregroundStyle(PingTheme.Color.contentPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .pingStatusCardStyle(tint: isError ? PingTheme.Color.statusError : PingTheme.Color.statusSuccess)
    }
}
