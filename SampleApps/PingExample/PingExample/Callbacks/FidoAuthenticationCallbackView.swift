//
//  FidoAuthenticationCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoAuthenticationCallbackView: View {
    var callback: FidoAuthenticationCallback
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("FIDO Authentication")
                .font(.title)
            Button(action: {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    callback.authenticate(window: window) { error in
                        if let error = error {
                            print("FIDO Authentication failed: \(error.localizedDescription)")
                        }
                        onNext()
                    }
                }
            }) {
                Text("Authenticate with FIDO")
            }
        }
    }
}
