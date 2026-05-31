//
//  DeviceFlowView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import PingOidc

// MARK: - ViewModel

@MainActor
final class DeviceFlowViewModel: ObservableObject {

    enum State {
        case idle
        case active(pollCount: Int?, nextPollAt: Date?)   // started + polling share one state
        case accessDenied
        case expired
        case failure(String)
    }

    @Published var state: State = .idle
    @Published var isLoading = false
    @Published var isSuccess = false

    // Retained once received; never cleared while flow is active.
    @Published var userCode: String = ""
    @Published var verificationUri: String = ""
    @Published var verificationUriComplete: String? = nil

    private var streamTask: Task<Void, Never>?

    func start() {
        guard let client = ConfigurationManager.shared.deviceClient else { return }
        isLoading = true
        // cancel() signals cancellation; the in-flight poll exits on the next Task.sleep check.
        // Production code should await the task before starting a new one to prevent two flows running concurrently.
        streamTask?.cancel()

        streamTask = Task {
            do {
                let stream = try await client.deviceAuthorization()
                for try await status in stream {
                    switch status {
                    case .started(let response):
                        userCode = response.userCode
                        verificationUri = response.verificationUri
                        verificationUriComplete = response.verificationUriComplete
                        isLoading = false
                        state = .active(pollCount: nil, nextPollAt: nil)
                    case .polling(let count, _, let nextPollAt):
                        isLoading = false
                        state = .active(pollCount: count, nextPollAt: nextPollAt)
                    case .success:
                        isLoading = false
                        isSuccess = true
                    case .accessDenied:
                        isLoading = false
                        state = .accessDenied
                    case .expired:
                        isLoading = false
                        state = .expired
                    case .failure(let error):
                        isLoading = false
                        state = .failure(error.localizedDescription)
                    }
                }
            } catch {
                if error is CancellationError { return }
                isLoading = false
                state = .failure(error.localizedDescription)
            }
        }
    }

    func authorize() {
        guard let client = ConfigurationManager.shared.deviceClient,
              let uriComplete = verificationUriComplete else { return }
        Task { try? await client.authorize(verificationUriComplete: uriComplete) }
    }

    func hasExistingUser() async -> Bool {
        guard let client = ConfigurationManager.shared.deviceClient else { return false }
        return await client.user() != nil
    }

    func reset() {
        // cancel() signals cancellation; production code should await the task value before
        // treating the flow as fully stopped to avoid two flows running concurrently.
        streamTask?.cancel()
        streamTask = nil
        isLoading = false
        isSuccess = false
        userCode = ""
        verificationUri = ""
        verificationUriComplete = nil
        state = .idle
    }
}

// MARK: - View

struct DeviceFlowView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = DeviceFlowViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content
            }
            .padding(20)
        }
        .navigationTitle("Device Flow")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.reset() }
        .onChange(of: viewModel.isSuccess) { success in
            if success {
                path.removeLast()
                path.append(.deviceToken)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleCard
            orDivider
            approveCard

        case .active(let pollCount, let nextPollAt):
            activationCard
            pollingStatusCard(pollCount: pollCount, nextPollAt: nextPollAt)

        case .accessDenied:
            resultCard(
                icon: "xmark.circle.fill",
                iconColor: .red,
                title: "Access Denied",
                message: "The authorization request was denied."
            )

        case .expired:
            resultCard(
                icon: "clock.badge.xmark",
                iconColor: .orange,
                title: "Expired",
                message: "The device code has expired. Please start a new flow."
            )

        case .failure(let message):
            resultCard(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                title: "Error",
                message: message
            )
        }
    }

    // MARK: - Idle

    private var idleCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv")
                .font(.system(size: 64))
                .foregroundColor(.themeButtonBackground)

            Text("Device Authorization Flow")
                .font(.system(size: 20, weight: .semibold))

            Text("Start the RFC 8628 device authorization grant. The server returns a user code and verification URL — enter them on another device (phone, laptop) to complete sign-in here.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.isLoading {
                ProgressView("Starting flow…")
            } else {
                Button {
                    Task {
                        if await viewModel.hasExistingUser() {
                            path.removeLast()
                            path.append(.deviceToken)
                        } else {
                            viewModel.start()
                        }
                    }
                } label: {
                    Text("Start Device Flow")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.themeButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Divider

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Approve

    private var approveCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.themeButtonBackground)

            Text("Approve a Device")
                .font(.system(size: 20, weight: .semibold))

            Text("This device is approving another device's request. Paste or scan the verification URL from the requesting device to complete sign-in there.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                path.append(.approveDevice)
            } label: {
                Text("Approve a Device")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.themeButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Activation (persists through polling)

    private var activationCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Activate Your Device")
                    .font(.system(size: 18, weight: .semibold))

                Text("Scan the QR code or visit the URL below and enter the code.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // QR code — prefer verificationUriComplete so the code is pre-filled on scan
            let qrContent = viewModel.verificationUriComplete ?? viewModel.verificationUri
            if !qrContent.isEmpty {
                QRCodeDisplayView(content: qrContent)
                    .frame(width: 180, height: 180)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 4) {
                Text("User Code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                CopyableRow {
                    Text(viewModel.userCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.themeButtonBackground)
                } value: { viewModel.userCode }
            }

            VStack(spacing: 4) {
                Text("Verification URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                CopyableRow {
                    Text(viewModel.verificationUriComplete ?? viewModel.verificationUri)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                } value: { viewModel.verificationUriComplete ?? viewModel.verificationUri }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Polling Status

    private func pollingStatusCard(pollCount: Int?, nextPollAt: Date?) -> some View {
        HStack(spacing: 12) {
            ProgressView()

            if let count = pollCount, let next = nextPollAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(next.timeIntervalSince(context.date).rounded()))
                    let timeStr = next.formatted(.dateTime.hour().minute().second())
                    Text("Poll #\(count) — next in \(remaining)s (at \(timeStr))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Waiting for authorization…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Result

    private func resultCard(icon: String, iconColor: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: 20, weight: .semibold))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.reset()
            } label: {
                Text("Start New Flow")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.themeButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Copyable Row

private struct CopyableRow<Label: View>: View {
    @ViewBuilder let label: () -> Label
    let value: () -> String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            HStack(spacing: 10) {
                label()
                    .frame(maxWidth: .infinity)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15))
                    .foregroundColor(copied ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: copied)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QR Code

private struct QRCodeDisplayView: View {
    let content: String

    var body: some View {
        if let image = makeQRCode(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    private func makeQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
