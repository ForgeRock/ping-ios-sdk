// 
//  NameCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct NameCallbackView: View {
    let callback: NameCallback
    let onNodeUpdated: () -> Void
    /// Set by the caller when this node also carries a `FidoAuthenticationCallback` requesting
    /// WebAuthn Conditional UI — only then does this field hint `.textContentType(.username)` for
    /// autofill-assisted passkey sign-in.
    var isConditionalMediationActive: Bool = false

    @State var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Text(callback.prompt)
                .pingSectionHeader()

            TextField(callback.prompt, text: $text)
                .pingTextFieldStyle()
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(isConditionalMediationActive ? .username : nil)
                .onSubmit(onNodeUpdated)
        }
        .onAppear { text = callback.name }
        .onChange(of: text) { callback.name = $0 }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
