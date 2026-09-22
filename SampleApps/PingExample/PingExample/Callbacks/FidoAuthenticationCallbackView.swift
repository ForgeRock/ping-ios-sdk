//
//  FidoAuthenticationCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoAuthenticationCallbackView: View {
    var callback: FidoAuthenticationCallback
    let onNext: () -> Void

    @State private var preferImmediatelyAvailableCredentials = false

    var body: some View {
        VStack {
            // isManualButtonEnabled only modifies the Conditional UI case ("also show a manual
            // fallback button alongside autofill") — outside that case, the button is the only
            // way to trigger authentication at all, so it must always show. The title hides with
            // the button: in the autofill-only case the passkey suggestion lives in the QuickType
            // bar of the sibling username field, and a heading with nothing beneath it would just
            // look broken.
            if !callback.isConditionalMediationRequested || callback.isManualButtonEnabled {
                Text("FIDO Authentication")
                    .font(.title)

                Toggle("Local credentials only", isOn: $preferImmediatelyAvailableCredentials)
                    .padding(.horizontal)

                Button(action: {
                    Task {
                        guard let window = currentWindow() else {
                            print("Could not find active window scene.")
                            return
                        }

                        let result = await callback.authenticate(
                            window: window,
                            preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
                        )

                        switch result {
                        case .success(let responseDict):
                            print("FIDO Authentication successful: \(responseDict)")
                            onNext()
                        case .failure(FidoError.canceled):
                            // A superseded ceremony (e.g. this button double-tapped, superseding
                            // ceremony A with ceremony B) must not advance the journey — the
                            // superseding ceremony is still in flight and will call onNext() when
                            // it resolves. Do NOT skip on native ASAuthorizationError.canceled
                            // here: a user-dismissed modal is still reported to the server as
                            // NotAllowedError and advances, as before this change.
                            print("FIDO Authentication was superseded by a newer ceremony")
                        case .failure(let error):
                            print("FIDO Authentication failed: \(error.localizedDescription)")
                            onNext()
                        }
                    }
                }) {
                    Text("Authenticate with FIDO")
                }
            }
        }
        .task {
            // Conditional UI (autofill-assisted sign-in): the server signals this is expected via
            // isConditionalMediationRequested. Runs silently in the background — the passkey
            // suggestion is surfaced by iOS in the QuickType bar of whichever text field on screen
            // has `.textContentType(.username)`, not by this view.
            //
            // No separate .onDisappear teardown here: SwiftUI cancels this `.task`'s underlying
            // Task when the view leaves the hierarchy, which propagates into
            // authenticateWithAutoFill's own `withTaskCancellationHandler` and calls
            // `fido.cancel()` from there. A second, independent `.onDisappear { callback.cancel() }`
            // would just be the same teardown reachable via two paths with different latency.
            guard callback.isConditionalMediationRequested, let window = currentWindow() else {
                return
            }

            let result = await callback.authenticateWithAutoFill(window: window)

            switch result {
            case .success(let responseDict):
                print("FIDO Conditional UI authentication successful: \(responseDict)")
                onNext()
            case .failure(let error):
                // A failed/cancelled/superseded autofill listener (e.g. no passkey chosen yet, or
                // the manual button superseded it) is not a reason to advance the node — only a
                // successful ceremony should.
                print("FIDO Conditional UI authentication did not complete: \(error.localizedDescription)")
            }
        }
    }

    private func currentWindow() -> UIWindow? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window
    }
}
