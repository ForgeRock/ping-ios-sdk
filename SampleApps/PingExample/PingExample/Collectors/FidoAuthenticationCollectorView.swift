//
//  FidoAuthenticationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoAuthenticationCollectorView: View {
    var collector: FidoAuthenticationCollector
    let onNext: () -> Void

    @State private var preferImmediatelyAvailableCredentials = false

    var body: some View {
        VStack {
            Text("FIDO Authentication")
                .font(.title)

            Toggle("Local credentials only", isOn: $preferImmediatelyAvailableCredentials)
                .padding(.horizontal)

            Button(action: {
                Task {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else {
                        print("Could not find active window scene.")
                        return
                    }

                    let result = await collector.authenticate(
                        window: window,
                        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
                    )

                    switch result {
                    case .success(let assertionValue):
                        print("FIDO Authentication successful: \(assertionValue)")
                        onNext()
                    case .failure(let error):
                        print("FIDO Authentication failed: \(error.localizedDescription)")
                    }
                }
            }) {
                if collector.label.isEmpty {
                    Text("Authenticate with FIDO")
                } else {
                    Text(collector.label)
                }
            }
        }
    }
}
