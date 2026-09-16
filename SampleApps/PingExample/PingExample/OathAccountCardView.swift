//
//  OathAccountCardView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOath

/// A SwiftUI view representing an OATH account card with code generation.
/// Tapping the card opens a view with detailed information.
struct OathAccountCardView: View {
    let credential: OathCredential
    @ObservedObject var timerService: OathTimerService
    let onTap: () -> Void

    // Computed properties for real-time updates
    private var code: String {
        timerService.generatedCodes[credential.id]?.code ?? "------"
    }

    private var timeRemaining: Int {
        guard credential.oathType == .totp else { return 0 }
        let now = Double(timerService.currentTimeMillis) / 1000.0
        let period = Double(credential.period)
        let elapsed = now.truncatingRemainder(dividingBy: period)
        return Int(period - elapsed)
    }

    private var progress: Double {
        guard credential.oathType == .totp else { return 0.0 }
        let now = Double(timerService.currentTimeMillis) / 1000.0
        let period = Double(credential.period)
        let elapsed = now.truncatingRemainder(dividingBy: period)
        return elapsed / period
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
                HStack(spacing: PingTheme.Spacing.medium) {
                    PingIconTile(systemName: typeIcon, diameter: 40, iconSize: 20, isLocked: credential.isLocked)

                    VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                        Text(credential.displayIssuer)
                            .pingSectionHeader()

                        Text(credential.displayAccountName)
                            .pingSupportingText()
                    }

                    Spacer()

                    if credential.oathType == .totp {
                        ZStack {
                            PingProgressRing(progress: progress, lineWidth: 3, diameter: 40)

                            Text("\(timeRemaining)")
                                .font(PingTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(PingTheme.Color.contentPrimary)
                        }
                    } else {
                        Button {
                            Task {
                                await timerService.generateCode(for: credential.id)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: PingTheme.Control.Glyph.medium))
                                .foregroundColor(PingTheme.Color.actionPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                HStack {
                    Text(code)
                        .font(PingTheme.Typography.codeSmall)
                        .foregroundColor(PingTheme.Color.actionPrimary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: PingTheme.Control.Glyph.small))
                            .foregroundColor(PingTheme.Color.actionPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .pingCardStyle()
        }
        .buttonStyle(.plain)
    }

    private var typeIcon: String {
        credential.oathType == .totp ? "clock.fill" : "number.circle.fill"
    }
}
