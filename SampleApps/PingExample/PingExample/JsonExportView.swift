//
//  JsonExportView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// Reusable view for displaying and exporting JSON data.
struct JsonExportView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let jsonData: String

    @State private var copied = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text(jsonData)
                        .font(PingTheme.Typography.monospacedCaption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pingCardStyle()
                        .pingScrollContentPadding(top: PingTheme.Spacing.small, bottom: 0)
                }

                HStack(spacing: PingTheme.Spacing.medium) {
                    Button {
                        UIPasteboard.general.string = jsonData
                        copied = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack(spacing: PingTheme.Spacing.small) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy to Clipboard")
                        }
                    }
                    .buttonStyle(PingActionButtonStyle(role: copied ? .affirmative : .primary))
                }
                .padding(PingTheme.Spacing.medium)
            }
            .pingScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Reusable export button component.
struct ExportButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PingTheme.Spacing.small) {
                Image(systemName: "square.and.arrow.up")
                Text("Export as JSON")
            }
        }
        .buttonStyle(.pingPrimary)
    }
}
