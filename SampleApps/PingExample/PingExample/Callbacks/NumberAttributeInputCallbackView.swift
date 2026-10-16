//
//  NumberAttributeInputCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct NumberAttributeInputCallbackView: View {
    let callback: NumberAttributeInputCallback
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
                .keyboardType(.decimalPad)
                .pingTextFieldStyle(showsError: hasErrors)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(onNodeUpdated)

            PingFieldMessages(errorMessages: errorMessages)
        }
        .onAppear { text = String(callback.value) }
        .onChange(of: text) { newValue in
            let filtered = newValue.filter { $0.isNumber || $0 == "." }
            if filtered != newValue {
                text = filtered
            }

            if !text.isEmpty, let doubleValue = Double(text) {
                callback.value = doubleValue
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
