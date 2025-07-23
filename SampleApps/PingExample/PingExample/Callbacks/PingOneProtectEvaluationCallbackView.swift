//
//  PingOneProtectEvaluationCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingProtect

struct PingOneProtectEvaluationCallbackView: View {
    let callback: PingOneProtectEvaluationCallback
    let onNext: () -> Void

    @State private var isLoading: Bool = true
    @State private var task: Task<Void, Never>?

    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

                Text("Collecting device profile ...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .onAppear {
                startEvaluation()
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
        }
    }

    private func startEvaluation() {
        isLoading = true
        let startTime = Date()

        task = Task {

            // Execute the evaluation
            _ = await callback.collect()

            // Calculate task duration
            let taskDuration = Date().timeIntervalSince(startTime)

            // If task completed too quickly, delay to meet minimum display time
            let minimumDisplayTime: TimeInterval = 2.0
            let remainingTime = minimumDisplayTime - taskDuration
            if remainingTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }

            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    onNext()
                }
            }
        }
    }
}
