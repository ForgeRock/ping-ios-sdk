//
//  PushAccountDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// View to display details of a push authentication account.
struct PushAccountDetailView: View {
    @Environment(\.dismiss) var dismiss
    let credential: PushCredential

    @State private var currentCredential: PushCredential?
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    @State private var editedIssuer = ""
    @State private var editedAccountName = ""
    @State private var errorMessage: String?
    @State private var showExportSheet = false
    @State private var showPolicySelectionSheet = false
    @State private var showUnlockAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: PingTheme.Spacing.large) {
                headerSection

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
        }
        .pingScreenBackground()
        .navigationTitle("Push Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .sheet(isPresented: $showExportSheet) {
            JsonExportView(title: "Push Credential JSON", jsonData: credentialToJson())
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
            Text("Are you sure you want to delete this push account? This action cannot be undone.")
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
            PingIconTile(systemName: "bell.badge.fill", diameter: 100, iconSize: 50, shape: .circle)

            Text(displayCredential.displayIssuer)
                .font(PingTheme.Typography.screenTitle.weight(.bold))
                .foregroundStyle(PingTheme.Color.contentPrimary)

            Text(displayCredential.displayAccountName)
                .pingBodySecondary()
        }
        .padding(PingTheme.Spacing.medium)
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Information")
                .pingScreenTitle()
                .padding(.bottom, PingTheme.Spacing.medium)

            PingInfoRow(label: "Status", value: "Active", labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Platform", value: credential.platform.rawValue, labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Created", value: formatDate(credential.createdAt), labelWidth: 90)

            if let userId = credential.userId {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "User ID", value: userId, labelWidth: 90)
            }
        }
        .pingCardStyle()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deleteAccount() async {
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }

        do {
            _ = try await client.deleteCredential(credentialId: credential.id)
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
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
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
        
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
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
        
        guard let client = ConfigurationManager.shared.pushClient else {
            errorMessage = "Push client not initialized"
            return
        }
        
        do {
            _ = try await client.saveCredential(credentialToUnlock)
            currentCredential = credentialToUnlock
        } catch {
            errorMessage = "Failed to unlock account: \(error.localizedDescription)"
        }
    }
}
