//
//  ManualOathRegistrationView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOath

/// View for manually registering an OATH account.
/// Allows users to input account details and save them.
struct ManualOathRegistrationView: View {
    @Binding var isPresented: Bool

    @State private var issuer: String = ""
    @State private var accountName: String = ""
    @State private var secretKey: String = ""
    @State private var oathType: OathType = .totp
    @State private var algorithm: OathAlgorithm = .sha256
    @State private var digits: Int = 6
    @State private var period: Int = 30

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: PingTheme.Spacing.large) {
                    formSection
                }
                .pingScrollContentPadding()
            }
            .pingScreenBackground()

            if isLoading {
                PingLoadingOverlay()
            }
        }
        .navigationTitle("Manual Registration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await saveAccount()
                    }
                }
                .disabled(!isFormValid)
            }
        }
        .pingErrorAlert(errorMessage: $errorMessage)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            FormField(title: "Issuer", text: $issuer, placeholder: "e.g., Google, GitHub")

            FormField(title: "Account Name", text: $accountName, placeholder: "e.g., user@example.com")

            FormField(title: "Secret Key", text: $secretKey, placeholder: "Base32-encoded secret", autocapitalization: .characters)

            VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                Text("Type")
                    .pingSectionHeader()

                Picker("Type", selection: $oathType) {
                    Text("TOTP (Time-based)").tag(OathType.totp)
                    Text("HOTP (Counter-based)").tag(OathType.hotp)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                Text("Algorithm")
                    .pingSectionHeader()

                Picker("Algorithm", selection: $algorithm) {
                    Text("SHA-1").tag(OathAlgorithm.sha1)
                    Text("SHA-256").tag(OathAlgorithm.sha256)
                    Text("SHA-512").tag(OathAlgorithm.sha512)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                Text("Digits")
                    .pingSectionHeader()

                Picker("Digits", selection: $digits) {
                    Text("6").tag(6)
                    Text("7").tag(7)
                    Text("8").tag(8)
                }
                .pickerStyle(.segmented)
            }

            if oathType == .totp {
                VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                    Text("Period (seconds)")
                        .pingSectionHeader()

                    Stepper("\(period) seconds", value: $period, in: 15...300, step: 15)
                }
            }

            infoSection
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            HStack(spacing: PingTheme.Spacing.small) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(PingTheme.Color.actionPrimary)

                Text("Tips")
                    .pingSectionHeader()
            }

            Text("• Secret key must be Base32-encoded (A-Z, 2-7)")
                .pingSupportingText()

            Text("• Most services use SHA-256 with 6 digits")
                .pingSupportingText()

            Text("• TOTP refreshes automatically, HOTP requires manual refresh")
                .pingSupportingText()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pingStatusCardStyle(tint: PingTheme.Color.actionPrimary)
    }

    private var isFormValid: Bool {
        !issuer.isEmpty && !accountName.isEmpty && !secretKey.isEmpty && isValidBase32(secretKey)
    }

    private func isValidBase32(_ string: String) -> Bool {
        let base32Pattern = "^[A-Z2-7]+=*$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", base32Pattern)
        return predicate.evaluate(with: string.uppercased())
    }

    private func saveAccount() async {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            if ConfigurationManager.shared.oathClient == nil {
                try await ConfigurationManager.shared.initializeOathClient()
            }
            guard let client = ConfigurationManager.shared.oathClient else {
                throw NSError(domain: "ManualRegistration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize OATH client"])
            }

            let credential = OathCredential(
                issuer: issuer,
                accountName: accountName,
                oathType: oathType,
                oathAlgorithm: algorithm,
                digits: digits,
                period: period,
                secretKey: secretKey.uppercased()
            )

            _ = try await client.saveCredential(credential)
            isPresented = false
        } catch {
            errorMessage = "Failed to save account: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Text(title)
                .pingSectionHeader()

            TextField(placeholder, text: $text)
                .pingTextFieldStyle()
                .textInputAutocapitalization(autocapitalization)
        }
    }
}
