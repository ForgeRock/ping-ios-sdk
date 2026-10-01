//
//  ConfirmationCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct ConfirmationCallbackView: View {
    let callback: ConfirmationCallback
    let onSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            // Display prompt if available
            if !callback.prompt.isEmpty {
                Text(callback.prompt)
                    .pingSectionHeader()
                    .multilineTextAlignment(.leading)
            }

            // Buttons arranged horizontally, trailing-aligned
            HStack {
                Spacer()

                ForEach(callback.options.indices, id: \.self) { index in
                    Button(callback.options[index]) {
                        callback.selectedIndex = index
                        onSelected()
                    }
                    .buttonStyle(.pingPrimary)
                    .padding(.horizontal, PingTheme.Spacing.xSmall)
                }
            }
        }
    }
}
