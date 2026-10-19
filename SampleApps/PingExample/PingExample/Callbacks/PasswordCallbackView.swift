// 
//  PasswordCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct PasswordCallbackView: View {

    var callback: PasswordCallback
    var onNodeUpdated: () -> Void

    @State var text: String = ""
    @State private var passwordVisibility: Bool = false

    var body: some View {
        PingSecureField(
            label: callback.prompt,
            text: $text,
            isVisible: $passwordVisibility,
            onSubmit: onNodeUpdated
        )
        .onAppear { text = callback.password }
        .onChange(of: text) { callback.password = $0 }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}

