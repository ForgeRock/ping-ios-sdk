//
//  PinCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingBinding

struct PinCollectorView: View {
    let prompt: Prompt
    let completion: (String?) -> Void
    
    @State private var pin: String = ""
    @FocusState private var isPinFocused: Bool
    
    var body: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            Text(prompt.title)
                .pingScreenTitle()
            Text(prompt.description)
                .pingSupportingText()

            TextField("4-digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .focused($isPinFocused)
                .onChange(of: pin) { newValue in
                    // Limit to 4 digits
                    if newValue.count > 4 {
                        pin = String(newValue.prefix(4))
                    }
                }
                .multilineTextAlignment(.center)
                .font(PingTheme.Typography.sectionTitle)
                .pingTextFieldStyle()

            HStack(spacing: PingTheme.Spacing.small) {
                Button("Cancel") {
                    completion(nil)
                }
                .buttonStyle(.pingDestructive)

                Button("Submit") {
                    completion(pin)
                }
                .buttonStyle(.pingPrimary)
                .disabled(pin.count != 4)
            }
        }
        .padding(PingTheme.Spacing.screen)
        .onAppear {
            isPinFocused = true
        }
    }
}
