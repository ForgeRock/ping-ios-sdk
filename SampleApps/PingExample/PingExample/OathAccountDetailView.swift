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

    @State private var code: String = "------"
    @State private var timeRemaining: Int = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                codeSection

                accountInfoSection

                Spacer()

                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
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
        .task {
            await generateCode()
            if credential.oathType == .totp {
                startTimer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: credential.oathType == .totp ? "clock.fill" : "number.circle.fill")
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

            Text(credential.displayIssuer)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(credential.displayAccountName)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var codeSection: some View {
        VStack(spacing: 16) {
            if credential.oathType == .totp {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.themeButtonBackground, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(timeRemaining)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)

                        Text("seconds")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.themeButtonBackground)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

            if credential.oathType == .hotp {
                Button {
                    Task {
                        await generateCode()
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

    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            Text("Delete Account")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
        }
    }

    private var algorithmName: String {
        switch credential.oathAlgorithm {
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        @unknown default: return "SHA-1"
        }
    }

    private func generateCode() async {
        guard let client = ConfigurationManager.shared.oathClient else { return }

        do {
            let codeInfo = try await client.generateCodeWithValidity(credential.id)
            code = codeInfo.code
            timeRemaining = codeInfo.timeRemaining
            progress = codeInfo.progress
        } catch {
            code = "ERROR"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                await updateCode()
            }
        }
    }

    private func updateCode() async {
        guard let client = ConfigurationManager.shared.oathClient else { return }

        do {
            let codeInfo = try await client.generateCodeWithValidity(credential.id)
            code = codeInfo.code
            timeRemaining = codeInfo.timeRemaining
            progress = codeInfo.progress
        } catch {
            code = "ERROR"
        }
    }

    private func deleteAccount() async {
        guard let client = ConfigurationManager.shared.oathClient else { return }

        do {
            _ = try await client.deleteCredential(credential.id)
            dismiss()
        } catch {
            // Handle error
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
