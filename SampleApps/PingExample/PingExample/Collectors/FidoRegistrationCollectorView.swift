//
//  FidoRegistrationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoRegistrationCollectorView: View {
    var collector: FidoRegistrationCollector
    let onNext: () -> Void

    // Note: The async Result version of `register` currently doesn't accept deviceName.
    // If needed, modify the collector's async method.
    @State private var deviceName: String = ""

    // Ensures the ceremony is launched at most once per view instance — starting a second
    // ASAuthorizationController request while one is in flight fails the ceremony. A fresh
    // collector (and therefore a fresh view, see ContinueNodeView's .id(ObjectIdentifier(...)))
    // resets this back to false.
    @State private var hasLaunched = false
    @State private var failureMessage: String?

    var body: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            Text("FIDO Registration")
                .pingScreenTitle()

            if collector.isAutomatic {
                if let failureMessage {
                    PingFieldMessages(errorMessages: [failureMessage])
                    HStack(spacing: PingTheme.Spacing.medium) {
                        Button("Try again") {
                            self.failureMessage = nil
                            hasLaunched = false
                            Task {
                                hasLaunched = true
                                await performRegistration()
                            }
                        }
                        .buttonStyle(.pingSecondary)
                        Button("Continue") {
                            onNext()
                        }
                        .buttonStyle(.pingPrimary)
                    }
                } else {
                    PingLoadingSpinner()
                    Text("Waiting for passkey…")
                        .pingSupportingText()
                }
            } else {
                // TextField remains, but isn't used by the async call below
                TextField("Device Name (Optional)", text: $deviceName)
                    .pingTextFieldStyle(showsError: false)
                    .padding(.vertical, PingTheme.Spacing.small)

                Button(action: {
                    Task {
                        await performRegistration()
                    }
                }) {
                    if collector.label.isEmpty {
                        Text("Register with FIDO")
                    } else {
                        Text(collector.label)
                    }
                }
                .buttonStyle(.pingPrimary)
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
        .task {
            guard collector.isAutomatic, !hasLaunched else { return }
            hasLaunched = true
            await performRegistration()
        }
    }

    private func performRegistration() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("Could not find active window scene.")
            return
        }

        let result = await collector.register(window: window)

        switch result {
        case .success(let attestationValue):
            print("FIDO Registration successful: \(attestationValue)")
            onNext()
        case .failure(let error):
            print("FIDO Registration failed: \(error.localizedDescription)")
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
