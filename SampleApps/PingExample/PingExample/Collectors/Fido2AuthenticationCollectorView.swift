//
//  Fido2AuthenticationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido2

struct Fido2AuthenticationCollectorView: View {
    var collector: Fido2AuthenticationCollector
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("FIDO2 Authentication")
                .font(.title)
            Button(action: {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    collector.authenticate(window: window) { result in
                        switch result {
                        case .success:
                            onNext()
                        case .failure(let error):
                            print("FIDO2 Authentication failed: \(error.localizedDescription)")
                        }
                    }
                }
            }) {
                Text("Authenticate with FIDO2")
            }
        }
    }
}
