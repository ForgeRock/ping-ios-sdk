//
//  MobilePairingCollectorView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOneMFA

struct MobilePairingCollectorView: View {
    private enum Phase {
        case pairing
        case success
        case failure(code: String, message: String)
        case initializationFailure(message: String)
    }

    let collector: MobilePairingCollector
    let onNext: () async -> Void

    @State private var phase: Phase = .pairing
    @State private var pairingTask: Task<Void, Never>?
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            switch phase {
            case .pairing:
                PingLoadingSpinner()
                Text("Pairing your device…")
                    .pingSupportingText()
                actionButton("Cancel", role: .destructive) {
                    Task { await cancel() }
                }
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: PingTheme.Control.Glyph.large))
                    .foregroundStyle(PingTheme.Color.statusSuccess)
                Text("Pairing successful")
                    .pingSectionHeader()
                actionButton("Continue", role: .primary) {
                    Task { await submit() }
                }
            case let .initializationFailure(message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: PingTheme.Control.Glyph.large))
                    .foregroundStyle(PingTheme.Color.statusWarning)
                Text("Unable to initialize PingOne MFA")
                    .pingSectionHeader()
                Text(message)
                    .pingSupportingText()
                    .multilineTextAlignment(.center)
                actionButton("Retry", role: .primary) {
                    startPairingIfNeeded(forceRetry: true)
                }
            case let .failure(code, message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: PingTheme.Control.Glyph.large))
                    .foregroundStyle(PingTheme.Color.statusWarning)
                Text("Pairing failed")
                    .pingSectionHeader()
                Text(code)
                    .font(PingTheme.Typography.monospacedCaption)
                Text(message)
                    .pingSupportingText()
                    .multilineTextAlignment(.center)
                actionButton("Continue", role: .primary) {
                    Task { await submit() }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PingTheme.Spacing.small)
        .onAppear { startPairingIfNeeded() }
        .onDisappear {
            pairingTask?.cancel()
            pairingTask = nil
        }
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        role: PingButtonRole,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(PingActionButtonStyle(role: role))
            .disabled(isSubmitting)
    }

    private func startPairingIfNeeded(forceRetry: Bool = false) {
        guard pairingTask == nil || forceRetry else { return }
        pairingTask?.cancel()
        pairingTask = Task { @MainActor in
            do {
                try await ConfigurationManager.shared.initializePingOneMFAClient()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                pairingTask = nil
                phase = .initializationFailure(message: error.localizedDescription)
                return
            }

            guard !Task.isCancelled else { return }
            let result = await collector.collect()
            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                phase = .success
            case .failure:
                phase = failurePhase(from: collector.payload())
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await onNext()
    }

    private func cancel() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        collector.cancel()
        pairingTask?.cancel()
        await onNext()
    }

    private func failurePhase(from payload: [String: Any]?) -> Phase {
        let error = payload?["error"] as? [String: Any]
        let code = error?["code"] as? String ?? "INTERNAL_ERROR"
        let message = error?["message"] as? String ?? "Pairing failed"
        return .failure(code: code, message: message)
    }
}
