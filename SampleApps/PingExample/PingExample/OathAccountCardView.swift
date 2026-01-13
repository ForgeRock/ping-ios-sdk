//
//  OathAccountCardView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: typeIcon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        if credential.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(credential.displayIssuer)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(credential.displayAccountName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if credential.oathType == .totp {
                        CircularProgressView(progress: progress, timeRemaining: timeRemaining)
                            .frame(width: 40, height: 40)
                    } else {
                        Button {
                            Task {
                                await timerService.generateCode(for: credential.id)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.themeButtonBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                HStack {
                    Text(code)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.themeButtonBackground)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(.themeButtonBackground)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(16)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeIcon: String {
        credential.oathType == .totp ? "clock.fill" : "number.circle.fill"
    }
}

struct CircularProgressView: View {
    let progress: Double
    let timeRemaining: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.themeButtonBackground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(timeRemaining)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
