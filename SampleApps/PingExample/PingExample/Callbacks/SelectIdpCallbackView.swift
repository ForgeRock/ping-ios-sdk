//
//  SelectIdpCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingExternalIdP

struct SelectIdpCallbackView: View {
    let callback: SelectIdpCallback
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {

            LazyVStack(alignment: .center, spacing: PingTheme.Spacing.compact) {

                // Add a title for better context
                Text("Select a provider")
                    .pingSectionHeader()
                    .padding(.bottom, PingTheme.Spacing.small)

                ForEach(callback.providers) { provider in
                    Button(action: {
                        callback.value = provider.provider
                        self.onNext()
                    }) {
                        // Make the button label more descriptive and visually appealing
                        Text(provider.provider.capitalized)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pingPrimary)
                }
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
