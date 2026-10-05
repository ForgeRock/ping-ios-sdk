//
//  DeviceFlowView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: PingTheme.Spacing.medium) {
                content
            }
            .padding(PingTheme.Spacing.screen)
        }
        .pingScreenBackground()
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
                iconColor: PingTheme.Color.statusError,
                title: "Access Denied",
                message: "The authorization request was denied."
            )

        case .expired:
            resultCard(
                icon: "clock.badge.xmark",
                iconColor: PingTheme.Color.statusWarning,
                title: "Expired",
                message: "The device code has expired. Please start a new flow."
            )

        case .failure(let message):
            // Semantically an error rather than a warning; corrected from the
            // legacy raw-orange treatment to match the rest of the app.
            resultCard(
                icon: "exclamationmark.triangle.fill",
                iconColor: PingTheme.Color.statusError,
                title: "Error",
                message: message
            )
        }
    }

    // MARK: - Idle

    private var idleCard: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            Image(systemName: "tv")
                .font(.system(size: PingTheme.Control.Glyph.heroLarge))
                .foregroundStyle(PingTheme.Color.actionPrimary)

            Text("Device Authorization Flow")
                .pingScreenTitle()

            Text("Start the RFC 8628 device authorization grant. The server returns a user code and verification URL — enter them on another device (phone, laptop) to complete sign-in here.")
                .pingSupportingText()
                .multilineTextAlignment(.center)

            if viewModel.isLoading {
                PingLoadingSpinner()
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
                }
                .buttonStyle(.pingPrimary)
            }
        }
        .pingCardStyle(size: .large)
    }

    // MARK: - Divider

    private var orDivider: some View {
        HStack(spacing: PingTheme.Spacing.small) {
            Rectangle()
                .fill(PingTheme.Color.contentSecondary.opacity(0.3))
                .frame(height: 1)
            Text("OR")
                .font(PingTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(PingTheme.Color.contentSecondary)
            Rectangle()
                .fill(PingTheme.Color.contentSecondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, PingTheme.Spacing.xSmall)
    }

    // MARK: - Approve

    private var approveCard: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: PingTheme.Control.Glyph.heroLarge))
                .foregroundStyle(PingTheme.Color.actionPrimary)

            Text("Approve a Device")
                .pingScreenTitle()

            Text("This device is approving another device's request. Paste or scan the verification URL from the requesting device to complete sign-in there.")
                .pingSupportingText()
                .multilineTextAlignment(.center)

            Button {
                path.append(.approveDevice)
            } label: {
                Text("Approve a Device")
            }
            .buttonStyle(.pingPrimary)
        }
        .pingCardStyle(size: .large)
    }

    // MARK: - Activation (persists through polling)

    private var activationCard: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            VStack(spacing: PingTheme.Spacing.small) {
                Text("Activate Your Device")
                    .pingSectionHeader()

                Text("Scan the QR code or visit the URL below and enter the code.")
                    .pingSupportingText()
                    .multilineTextAlignment(.center)
            }

            // QR code — prefer verificationUriComplete so the code is pre-filled on scan
            let qrContent = viewModel.verificationUriComplete ?? viewModel.verificationUri
            if !qrContent.isEmpty {
                QRCodeDisplayView(content: qrContent)
                    .frame(width: 180, height: 180)
                    .padding(PingTheme.Spacing.small)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
            }

            VStack(spacing: PingTheme.Spacing.xSmall) {
                Text("User Code")
                    .pingCaptionText()
                    .textCase(.uppercase)

                CopyableRow {
                    Text(viewModel.userCode)
                        .font(PingTheme.Typography.code)
                        .foregroundStyle(PingTheme.Color.actionPrimary)
                } value: { viewModel.userCode }
            }

            VStack(spacing: PingTheme.Spacing.xSmall) {
                Text("Verification URL")
                    .pingCaptionText()
                    .textCase(.uppercase)

                CopyableRow {
                    Text(viewModel.verificationUriComplete ?? viewModel.verificationUri)
                        .font(PingTheme.Typography.monospacedCaption)
                        .foregroundStyle(PingTheme.Color.contentPrimary)
                        .multilineTextAlignment(.center)
                } value: { viewModel.verificationUriComplete ?? viewModel.verificationUri }
            }
        }
        .pingCardStyle(size: .large)
    }

    // MARK: - Polling Status

    private func pollingStatusCard(pollCount: Int?, nextPollAt: Date?) -> some View {
        HStack(spacing: PingTheme.Spacing.small) {
            PingLoadingSpinner()

            if let count = pollCount, let next = nextPollAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(next.timeIntervalSince(context.date).rounded()))
                    let timeStr = next.formatted(.dateTime.hour().minute().second())
                    Text("Poll #\(count) — next in \(remaining)s (at \(timeStr))")
                        .pingSupportingText()
                }
            } else {
                Text("Waiting for authorization…")
                    .pingSupportingText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pingCardStyle()
    }

    // MARK: - Result

    private func resultCard(icon: String, iconColor: Color, title: String, message: String) -> some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: PingTheme.Control.Glyph.hero))
                .foregroundStyle(iconColor)

            Text(title)
                .pingScreenTitle()

            Text(message)
                .pingSupportingText()
                .multilineTextAlignment(.center)

            Button {
                viewModel.reset()
            } label: {
                Text("Start New Flow")
            }
            .buttonStyle(.pingPrimary)
        }
        .pingCardStyle(size: .large)
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
            HStack(spacing: PingTheme.Spacing.compact) {
                label()
                    .frame(maxWidth: .infinity)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: PingTheme.Control.Glyph.small))
                    .foregroundColor(copied ? PingTheme.Color.statusSuccess : PingTheme.Color.contentSecondary)
                    .animation(.easeInOut(duration: 0.2), value: copied)
            }
            .padding(.horizontal, PingTheme.Spacing.medium)
            .padding(.vertical, PingTheme.Spacing.compact)
            .background(PingTheme.Color.groupedSurface)
            .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.tileRadius))
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
