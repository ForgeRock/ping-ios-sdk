//
//  TermsAndConditionsCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct TermsAndConditionsCallbackView: View {
    let callback: TermsAndConditionsCallback
    let onNodeUpdated: () -> Void

    @State var accepted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            // Version
            if !callback.version.isEmpty {
                Text(callback.version)
                    .pingSectionHeader()
            }

            // Create Date
            if !callback.createDate.isEmpty {
                Text(callback.createDate)
                    .pingSectionHeader()
            }

            // Terms Text
            if !callback.terms.isEmpty {
                Text(callback.terms)
                    .pingSupportingText()
                    .multilineTextAlignment(.leading)
            }

            // Acceptance Toggle
            Toggle("I accept the terms and conditions", isOn: $accepted)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: accepted) { newValue in
                    callback.accepted = newValue
                }
        }
        .onAppear {
            accepted = callback.accepted
        }
    }
}
