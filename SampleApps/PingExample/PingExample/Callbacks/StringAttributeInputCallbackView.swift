//
//  StringAttributeInputCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct StringAttributeInputCallbackView: View {
    let callback: StringAttributeInputCallback
    let onNodeUpdated: () -> Void

    @State var text: String = ""

    private var hasErrors: Bool {
        !callback.failedPolicies.isEmpty
    }

    var body: some View {
        let errorMessages = callback.failedPolicies.map { $0.failedDescription(for: callback.prompt) }

        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Text(callback.prompt)
                .pingSectionHeader()

            TextField(callback.prompt, text: $text)
                .pingTextFieldStyle(showsError: hasErrors)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(onNodeUpdated)

            PingFieldMessages(errorMessages: errorMessages)
        }
        .onAppear { text = callback.value }
        .onChange(of: text) { callback.value = $0 }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
