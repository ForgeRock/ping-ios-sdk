//
//  PollingWaitCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct PollingWaitCallbackView: View {
    let callback: PollingWaitCallback
    let onTimeout: () -> Void

    @State private var progress: Double = 0.0
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(callback.message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
        }
        .padding()
        .onAppear {
            startPolling()
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func startPolling() {
        progress = 0.0
        let waitTimeInSeconds = Double(callback.waitTime) / 1000.0
        let updateInterval = 0.1 // Update progress every 100ms for smooth animation
        let totalSteps = waitTimeInSeconds / updateInterval

        task = Task {
            for step in 0..<Int(totalSteps) {
                if Task.isCancelled { return }

                await MainActor.run {
                    progress = Double(step + 1) / totalSteps
                }

                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }

            if !Task.isCancelled {
                await MainActor.run {
                    onTimeout()
                }
            }
        }
    }
}
