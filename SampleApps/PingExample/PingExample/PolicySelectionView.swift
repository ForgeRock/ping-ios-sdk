//
//  PolicySelectionView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// View for selecting a policy when locking an account.
/// Presents radio button options for built-in policies.
struct PolicySelectionView: View {
    @Environment(\.dismiss) var dismiss
    let onPolicySelected: (String) -> Void

    /// Policy options with display names
    /// JSON formats:
    /// - Biometric Available: {"biometricAvailable": {}}
    /// - Device Tampering: {"deviceTampering": {"score": 0.8}}
    /// - Custom Policy: User-defined policy name
    private let policyOptions: [(policyName: String, displayName: String, description: String)] = [
        ("biometricAvailable", "Biometric Available", "Requires biometric authentication to be available on the device"),
        ("deviceTampering", "Device Tampering", "Checks for jailbreak and device tampering (threshold: 0.8)"),
        ("customPolicy", "Custom Policy", "User-defined custom locking policy")
    ]

    @State private var selectedPolicy: String

    init(onPolicySelected: @escaping (String) -> Void) {
        self.onPolicySelected = onPolicySelected
        _selectedPolicy = State(initialValue: "biometricAvailable")
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(policyOptions, id: \.policyName) { option in
                        Button {
                            selectedPolicy = option.policyName
                        } label: {
                            HStack(spacing: PingTheme.Spacing.compact) {
                                Image(systemName: selectedPolicy == option.policyName ? "circle.fill" : "circle")
                                    .foregroundStyle(selectedPolicy == option.policyName ? PingTheme.Color.actionPrimary : PingTheme.Color.contentSecondary)
                                    .font(.system(size: PingTheme.Control.Glyph.medium))

                                VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                                    Text(option.displayName)
                                        .font(PingTheme.Typography.body)
                                        .foregroundStyle(PingTheme.Color.contentPrimary)  // emphasized row title

                                    Text(option.description)
                                        .pingSupportingText()
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, PingTheme.Spacing.small)
                    }
                } header: {
                    Text("Select Locking Policy")
                        .font(PingTheme.Typography.sectionTitle)
                } footer: {
                    Text("The account will be locked according to the selected policy. It can only be used again after unlocking.")
                        .font(PingTheme.Typography.caption)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .pingScreenBackground()
            .navigationTitle("Lock Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lock") {
                        onPolicySelected(selectedPolicy)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    PolicySelectionView { policyName in
        print("Selected policy: \(policyName)")
    }
}
