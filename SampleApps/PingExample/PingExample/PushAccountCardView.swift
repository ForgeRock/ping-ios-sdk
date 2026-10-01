//
//  PushAccountCardView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// A SwiftUI view representing a push account card.
/// Displays information about a push credential.
struct PushAccountCardView: View {
    let credential: PushCredential
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            HStack(spacing: PingTheme.Spacing.medium) {
                PingIconTile(systemName: "bell.badge.fill", diameter: 40, iconSize: 20, isLocked: credential.isLocked)

                VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                    Text(credential.displayIssuer)
                        .pingSectionHeader()

                    Text(credential.displayAccountName)
                        .pingSupportingText()
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: PingTheme.Control.Glyph.medium))
                    .foregroundColor(PingTheme.Color.statusSuccess)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                    Text("Status")
                        .pingCaptionText()

                    Text("Active")
                        .font(PingTheme.Typography.supporting.weight(.medium))
                        .foregroundStyle(PingTheme.Color.statusSuccess)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PingTheme.Spacing.xSmall) {
                    Text("Created")
                        .pingCaptionText()

                    Text(credential.createdAt, style: .date)
                        .font(PingTheme.Typography.supporting.weight(.medium))
                        .foregroundStyle(PingTheme.Color.contentPrimary)
                }
            }
        }
        .pingCardStyle()
    }
}
