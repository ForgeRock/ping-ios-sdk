//
//  ConsentMappingCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct ConsentMappingCallbackView: View {
    let callback: ConsentMappingCallback
    let onNodeUpdated: () -> Void

    @State var accepted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            // Name
            if !callback.name.isEmpty {
                Text("Name: \(callback.name)")
                    .pingSectionHeader()
            }

            // Display Name
            if !callback.displayName.isEmpty {
                Text("DisplayName: \(callback.displayName)")
                    .pingSectionHeader()
            }

            // Icon
            if !callback.icon.isEmpty {
                Text("Icon: \(callback.icon)")
                    .pingSupportingText()
            }

            // Access Level
            if !callback.accessLevel.isEmpty {
                Text("AccessLevel: \(callback.accessLevel)")
                    .pingSupportingText()
            }

            // Is Required
            Text("IsRequired: \(callback.isRequired.description)")
                .pingSupportingText()

            // fields
            ForEach(callback.fields, id: \.self) { fieldItem in
                Text("callback: \(fieldItem)")
                    .pingSupportingText()
            }

            // Message
            if !callback.message.isEmpty {
                Text("Message: \(callback.message)")
                    .pingSupportingText()
            }

            // Acceptance Toggle
            Toggle("I consent to this mapping", isOn: $accepted)
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
