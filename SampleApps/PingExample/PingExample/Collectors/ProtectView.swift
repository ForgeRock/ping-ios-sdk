//
//  ProtectView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingProtect

struct ProtectView: View {
    let field: ProtectCollector
    let onNodeUpdated: () -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        if isLoading {
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .tint(.themeButtonBackground)

                    Text("Collecting device profile ...")
                        .font(.body)
                }
                .padding(16)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await performCollection()
            }
        }
    }

    private func performCollection() async {
        do {
            let startTime = Date()

            let _ = await field.collect()

            let taskDuration = Date().timeIntervalSince(startTime)
            let minimumDisplayTime: TimeInterval = 2.0

            // If task completed too quickly, delay to meet minimum display time
            let remainingTime = minimumDisplayTime - taskDuration
            if remainingTime > 0 {
                try await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }

            await MainActor.run {
                isLoading = false
                onNodeUpdated()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
