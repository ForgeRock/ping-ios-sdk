//
//  PushAccountDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: 24) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
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
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private var headerSection: some View {
        let displayCredential = currentCredential ?? credential
        return VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(
                    LinearGradient(
                        colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            Text(displayCredential.displayIssuer)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(displayCredential.displayAccountName)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Information")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            PushInfoRow(label: "Status", value: "Active")
            Divider().padding(.leading, 100)

            PushInfoRow(label: "Platform", value: credential.platform.rawValue)
            Divider().padding(.leading, 100)

            PushInfoRow(label: "Created", value: formatDate(credential.createdAt))
            
            if let userId = credential.userId {
                Divider().padding(.leading, 100)
                PushInfoRow(label: "User ID", value: userId)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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

struct PushInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 12)
    }
}
