//
//  FidoAuthenticationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoAuthenticationCollectorView: View {
    var collector: FidoAuthenticationCollector
    let onNext: () -> Void

    // Manual-mode demo affordance only. Hidden in automatic mode, which passes the default
    // `false` to `collector.authenticate(window:preferImmediatelyAvailableCredentials:)`.
    @State private var preferImmediatelyAvailableCredentials = false

    // Ensures the ceremony is launched at most once per view instance — starting a second
    // ASAuthorizationController request while one is in flight fails the ceremony. A fresh
    // collector (and therefore a fresh view, see ContinueNodeView's .id(ObjectIdentifier(...)))
    // resets this back to false.
    @State private var hasLaunched = false
    @State private var failureMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("FIDO Authentication")
                .font(.title)

            if collector.isAutomatic {
                if let failureMessage {
                    ErrorMessageView(errors: [failureMessage])
                    HStack(spacing: 16) {
                        Button("Try again") {
                            self.failureMessage = nil
                            hasLaunched = false
                            Task {
                                hasLaunched = true
                                await performAuthentication()
                            }
                        }
                        Button("Continue") {
                            onNext()
                        }
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .tint(.themeButtonBackground)
                    Text("Waiting for passkey…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Toggle("Local credentials only", isOn: $preferImmediatelyAvailableCredentials)
                    .padding(.horizontal)

                Button(action: {
                    Task {
                        await performAuthentication()
                    }
                }) {
                    if collector.label.isEmpty {
                        Text("Authenticate with FIDO")
                    } else {
                        Text(collector.label)
                    }
                }
            }
        }
        .padding()
        .task {
            guard collector.isAutomatic, !hasLaunched else { return }
            hasLaunched = true
            await performAuthentication()
        }
    }

    private func performAuthentication() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("Could not find active window scene.")
            return
        }

        let result = await collector.authenticate(
            window: window,
            preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
        )

        switch result {
        case .success(let assertionValue):
            print("FIDO Authentication successful: \(assertionValue)")
            onNext()
        case .failure(let error):
            print("FIDO Authentication failed: \(error.localizedDescription)")
            if collector.isAutomatic {
                // Automatic mode never auto-resubmits on failure, so the server never re-renders
                // the same FIDO step and re-triggers the ceremony without user intent.
                failureMessage = error.localizedDescription
            } else {
                onNext()
            }
        }
    }
}
