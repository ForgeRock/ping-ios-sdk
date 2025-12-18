//
//  OathAccountDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: 24) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                currentTime = Date()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    
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
            Image(systemName: displayCredential.oathType == .totp ? "clock.fill" : "number.circle.fill")
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

    private var codeSection: some View {
        let displayCredential = currentCredential ?? credential
        let isLocked = displayCredential.isLocked
        
        return VStack(spacing: 16) {
            if credential.oathType == .totp {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(isLocked ? Color.red.opacity(0.5) : Color.themeButtonBackground, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(timeRemaining)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text(isLocked ? "Locked" : "seconds")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if isLocked {
                VStack(spacing: 8) {
                    Text("------")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    
                    Text("Account is locked")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(code)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.themeButtonBackground)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themeButtonBackground)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Information")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            InfoRow(label: "Type", value: credential.oathType == .totp ? "TOTP (Time-based)" : "HOTP (Counter-based)")
            Divider().padding(.leading, 100)

            InfoRow(label: "Algorithm", value: algorithmName)
            Divider().padding(.leading, 100)

            InfoRow(label: "Digits", value: "\(credential.digits)")
            Divider().padding(.leading, 100)

            if credential.oathType == .totp {
                InfoRow(label: "Period", value: "\(credential.period) seconds")
            } else {
                InfoRow(label: "Counter", value: "\(credential.counter)")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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

struct InfoRow: View {
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

/// Reusable delete button component.
struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "trash")
                Text("Delete")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themeButtonBackground)
            .cornerRadius(12)
        }
    }
}

/// Reusable lock/unlock button component.
struct LockUnlockButton: View {
    let locked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: locked ? "lock.open.fill" : "lock.fill")
                Text(locked ? "Unlock Account" : "Lock Account")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themeButtonBackground)
            .cornerRadius(12)
        }
    }
}
