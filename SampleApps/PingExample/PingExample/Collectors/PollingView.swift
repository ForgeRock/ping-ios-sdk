//
//  PollingView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci

/// A view that drives the `PollingCollector` lifecycle and reflects its status to the user.
///
/// ## Polling behaviour
/// For every terminal status the view submits the collector's current `value` to the DaVinci
/// server by calling `onNext(false)`. The server then decides what to render next:
///
/// - `.complete(status: "continue")` (simple polling) — the collector slept for the configured
///   interval and emitted `value = "continue"`. `onNext` POSTs that value to the server, which
///   replies with the same step as a fresh `ContinueNode`. `Transform` creates a new
///   `PollingCollector` from JSON, and `continueNode.didSet` restores `retriesAllowed` from
///   `FlowContext` so the counter continues from where it left off.
///
/// - `.complete(status: other)` (challenge polling succeeded) — `onNext` submits the server
///   status and the flow advances to the next step.
///
/// - `.timedOut` / `.expired` — the respective terminal value is submitted so the server can
///   decide the next step.
///
/// - `.error` — the error is surfaced to the user. No automatic submission is made.
struct PollingView: View {
    let collector: PollingCollector
    let onNext: (Bool) -> Void

    @State private var currentStatus: PollingStatus

    init(collector: PollingCollector, onNext: @escaping (Bool) -> Void) {
        self.collector = collector
        self.onNext = onNext
        // Seed the initial UI state from the collector. After a DaVinci re-submission the fresh
        // PollingCollector restores retriesAllowed from FlowContext (in continueNode.didSet),
        // so the counter picks up from where the previous cycle left off rather than resetting.
        let total = collector.pollRetries
        let attempt = max(1, total - collector.retriesAllowed + 1)
        _currentStatus = State(initialValue: .continue(retryCount: attempt, maxRetries: total))
    }

    var body: some View {
        VStack(spacing: 16) {
            switch currentStatus {
            case .continue(let retry, let max):
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .tint(.themeButtonBackground)
                if max > 0 {
                    Text("Please wait… (\(retry)/\(max))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Please wait…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .complete:
                // Auto-submitting to server — no UI needed; handled in .task below
                EmptyView()

            case .timedOut:
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Request timed out.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

            case .expired:
                Image(systemName: "xmark.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text("The request has expired. Please try again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

            case .error(let error):
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text("An error occurred: \(error.localizedDescription)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .task {
            for await status in collector.poll() {
                await MainActor.run { currentStatus = status }

                switch status {
                case .complete, .timedOut, .expired:
                    // Submit the collector's current value to the server.
                    // Use onNext(false) to bypass form validation — this is an automatic
                    // submission, not a user-initiated form submit.
                    // For `.complete("continue")` the server returns a new ContinueNode with a
                    // fresh PollingCollector. ContinueNodeView uses .id(ObjectIdentifier(...))
                    // on PollingCollectorView, so SwiftUI recreates the view and restarts .task.
                    onNext(false)

                case .error:
                    // Surface the error; do not auto-submit.
                    break

                case .continue:
                    // In-flight update — UI already updated via currentStatus.
                    break
                }
            }
        }
        .onDisappear {
            collector.close()
        }
    }
}
