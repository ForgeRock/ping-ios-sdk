//
//  OathAccountDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOath

/// View to display details of an OATH account and manage codes.
struct OathAccountDetailView: View {
    @Environment(\.dismiss) var dismiss
    let credential: OathCredential

    @State private var currentCredential: OathCredential?
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    @State private var editedIssuer = ""
    @State private var editedAccountName = ""
    @State private var errorMessage: String?
    @State private var showExportSheet = false
    @State private var showPolicySelectionSheet = false
    @State private var showUnlockAlert = false
    
    // Get the timer service - will be set by parent view
    private var timerService: OathTimerService? {
        ConfigurationManager.shared.oathTimerService
    }
    
    // State to trigger UI updates
    @State private var currentTime: Date = Date()
    
    // Computed properties for real-time updates from shared service
    private var code: String {
        timerService?.generatedCodes[credential.id]?.code ?? "------"
    }
    
    private var timeRemaining: Int {
        guard credential.oathType == .totp else { return 0 }
        let now = currentTime.timeIntervalSince1970
        let period = Double(credential.period)
        let elapsed = now.truncatingRemainder(dividingBy: period)
        return Int(period - elapsed)
    }
    
    private var progress: Double {
        guard credential.oathType == .totp else { return 0.0 }
        let now = currentTime.timeIntervalSince1970
        let period = Double(credential.period)
        let elapsed = now.truncatingRemainder(dividingBy: period)
        return elapsed / period
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PingTheme.Spacing.large) {
                headerSection

                codeSection

                accountInfoSection

                Spacer()
                
                let displayCredential = currentCredential ?? credential
                let isLocked = displayCredential.isLocked
                LockUnlockButton(locked: isLocked) {
                    if isLocked {
                        showUnlockAlert = true
                    } else {
                        showPolicySelectionSheet = true
                    }
                }
                
                ExportButton {
                    showExportSheet = true
                }

                DeleteButton {
                    showDeleteAlert = true
                }
            }
            .pingScrollContentPadding()
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                currentTime = Date()
            }
        }
        .pingScreenBackground()
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: PingTheme.Spacing.medium) {
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy Code")

                    Button {
                        let displayCredential = currentCredential ?? credential
                        editedIssuer = displayCredential.displayIssuer
                        editedAccountName = displayCredential.displayAccountName
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Account")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .sheet(isPresented: $showExportSheet) {
            JsonExportView(title: "OATH Credential JSON", jsonData: credentialToJson())
        }
        .sheet(isPresented: $showPolicySelectionSheet) {
            PolicySelectionView { policyName in
                Task {
                    await lockAccount(policyName: policyName)
                }
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
        }
        .alert("Unlock Account", isPresented: $showUnlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unlock") {
                Task {
                    await unlockAccount()
                }
            }
        } message: {
            Text("Are you sure you want to unlock this account?")
        }
        .pingErrorAlert(errorMessage: $errorMessage)
    }
    
    private var headerSection: some View {
        let displayCredential = currentCredential ?? credential
        return VStack(spacing: PingTheme.Spacing.large) {
            PingIconTile(
                systemName: displayCredential.oathType == .totp ? "clock.fill" : "number.circle.fill",
                diameter: 100,
                iconSize: 50,
                shape: .circle
            )

            Text(displayCredential.displayIssuer)
                .font(PingTheme.Typography.screenTitle.weight(.bold))
                .foregroundStyle(PingTheme.Color.contentPrimary)

            Text(displayCredential.displayAccountName)
                .pingBodySecondary()
        }
        .padding(PingTheme.Spacing.medium)
    }

    private var codeSection: some View {
        let displayCredential = currentCredential ?? credential
        let isLocked = displayCredential.isLocked
        
        return VStack(spacing: PingTheme.Spacing.medium) {
            if credential.oathType == .totp {
                ZStack {
                    PingProgressRing(
                        progress: progress,
                        lineWidth: 8,
                        diameter: 120,
                        tint: isLocked ? PingTheme.Color.statusError : PingTheme.Color.actionPrimary
                    )

                    VStack(spacing: PingTheme.Spacing.xSmall) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(PingTheme.Typography.codeLarge)
                                .foregroundColor(PingTheme.Color.contentPrimary)
                        } else {
                            Text("\(timeRemaining)")
                                .font(PingTheme.Typography.codeLarge)
                                .foregroundColor(PingTheme.Color.contentPrimary)
                        }

                        Text(isLocked ? "Locked" : "seconds")
                            .pingCaptionText()
                    }
                }
            }

            if isLocked {
                VStack(spacing: PingTheme.Spacing.small) {
                    Text("------")
                        .font(PingTheme.Typography.code)
                        .foregroundColor(PingTheme.Color.contentSecondary)
                        .pingCardStyle()

                    Text("Account is locked")
                        .pingSupportingText()
                }
            } else {
                Text(code)
                    .font(PingTheme.Typography.code)
                    .foregroundColor(PingTheme.Color.actionPrimary)
                    .pingCardStyle()

                if credential.oathType == .hotp {
                    Button {
                        Task {
                            await timerService?.generateCode(for: credential.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Generate New Code")
                        }
                    }
                    .buttonStyle(.pingPrimary)
                }
            }
        }
        .pingCardStyle()
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Information")
                .pingScreenTitle()
                .padding(.bottom, PingTheme.Spacing.medium)

            PingInfoRow(label: "Type", value: credential.oathType == .totp ? "TOTP (Time-based)" : "HOTP (Counter-based)", labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Algorithm", value: algorithmName, labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Digits", value: "\(credential.digits)", labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            if credential.oathType == .totp {
                PingInfoRow(label: "Period", value: "\(credential.period) seconds", labelWidth: 90)
            } else {
                PingInfoRow(label: "Counter", value: "\(credential.counter)", labelWidth: 90)
            }
        }
        .pingCardStyle()
    }

    private var algorithmName: String {
        switch credential.oathAlgorithm {
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        @unknown default: return "SHA-1"
        }
    }

    private func deleteAccount() async {
        guard let client = ConfigurationManager.shared.oathClient else { return }

        do {
            _ = try await client.deleteCredential(credential.id)
            dismiss()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }
    
    private func credentialToJson() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let displayCredential = currentCredential ?? credential
        do {
            let data = try encoder.encode(displayCredential)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\n  \"error\": \"Failed to encode credential\"\n}"
        }
    }
    
    private var editSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Display Names")) {
                    TextField("Display Issuer", text: $editedIssuer)
                        .autocorrectionDisabled()
                    TextField("Display Account Name", text: $editedAccountName)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Original Values")) {
                    LabeledContent("Issuer", value: credential.issuer)
                    LabeledContent("Account", value: credential.accountName)
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(editedIssuer.trimmingCharacters(in: .whitespaces).isEmpty || 
                             editedAccountName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() async {
        guard let client = ConfigurationManager.shared.oathClient else {
            errorMessage = "OATH client not initialized"
            showEditSheet = false
            return
        }
        
        var updatedCredential = currentCredential ?? credential
        updatedCredential.displayIssuer = editedIssuer.trimmingCharacters(in: .whitespaces)
        updatedCredential.displayAccountName = editedAccountName.trimmingCharacters(in: .whitespaces)
        
        do {
            _ = try await client.saveCredential(updatedCredential)
            currentCredential = updatedCredential
            showEditSheet = false
        } catch {
            errorMessage = "Failed to update account: \(error.localizedDescription)"
            showEditSheet = false
        }
    }
    
    private func lockAccount(policyName: String) async {
        let displayCredential = currentCredential ?? credential
        var credentialToLock = displayCredential
        credentialToLock.lockCredential(policyName: policyName)
        
        guard let client = ConfigurationManager.shared.oathClient else {
            errorMessage = "OATH client not initialized"
            return
        }
        
        do {
            _ = try await client.saveCredential(credentialToLock)
            currentCredential = credentialToLock
        } catch {
            errorMessage = "Failed to lock account: \(error.localizedDescription)"
        }
    }
    
    private func unlockAccount() async {
        let displayCredential = currentCredential ?? credential
        var credentialToUnlock = displayCredential
        credentialToUnlock.unlockCredential()
        
        guard let client = ConfigurationManager.shared.oathClient else {
            errorMessage = "OATH client not initialized"
            return
        }
        
        do {
            _ = try await client.saveCredential(credentialToUnlock)
            currentCredential = credentialToUnlock
            
            // Generate code immediately after unlocking
            await timerService?.generateCode(for: credentialToUnlock.id)
        } catch {
            errorMessage = "Failed to unlock account: \(error.localizedDescription)"
        }
    }
}

/// Reusable delete button component.
struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "trash")
                Text("Delete")
            }
        }
        .buttonStyle(.pingDestructive)
    }
}

/// Reusable lock/unlock button component.
///
/// Locking/unlocking reads as a normal alternative action rather than a
/// caution, so it uses the secondary role rather than destructive/affirmative.
struct LockUnlockButton: View {
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: locked ? "lock.open.fill" : "lock.fill")
                Text(locked ? "Unlock Account" : "Lock Account")
            }
        }
        .buttonStyle(.pingSecondary)
    }
}
