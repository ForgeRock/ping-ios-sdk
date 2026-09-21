//
//  ValidatedUsernameCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct ValidatedUsernameCallbackView: View {
    let callback: ValidatedUsernameCallback
    let onNodeUpdated: () -> Void
    /// Set by the caller when this node also carries a `FidoAuthenticationCallback` requesting
    /// WebAuthn Conditional UI — only then does this field hint `.textContentType(.username)` for
    /// autofill-assisted passkey sign-in.
    var isConditionalMediationActive: Bool = false

    @State var text: String = ""

    private var hasErrors: Bool {
        !callback.failedPolicies.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                callback.prompt,
                text: $text
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(isConditionalMediationActive ? .username : nil)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hasErrors ? Color.red : Color.gray, lineWidth: 1)
            )
            .onAppear(perform: {
                text = callback.username
            })
            .onChange(of: text) { newValue in
                callback.username = newValue
            }
            .onSubmit {
                onNodeUpdated()
            }

            // Error message display
            if hasErrors {
                ErrorMessageView(errors: callback.failedPolicies.map({ $0.failedDescription(for: callback.prompt)}))
            }
        }
        .padding()
    }
}
