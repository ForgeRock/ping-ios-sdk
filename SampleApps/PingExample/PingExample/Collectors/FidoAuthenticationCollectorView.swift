//
//  FidoAuthenticationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoAuthenticationCollectorView: View {
    var collector: FidoAuthenticationCollector
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("FIDO Authentication")
                .font(.title)
            
            // 1. Button action still creates a Task
            Button(action: {
                Task {
                    // 2. Get the window (same as before)
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else {
                        print("Could not find active window scene.")
                        return // Exit if no window found
                    }
                    
                    // 3. Call the async function and await its Result
                    let result = await collector.authenticate(window: window)
                    
                    // 4. Handle the Result
                    switch result {
                    case .success(let assertionValue):
                        // Optional: Use assertionValue if needed, e.g., logging
                        print("FIDO Authentication successful: \(assertionValue)")
                        // Call onNext only on success
                        onNext()
                    case .failure(let error):
                        // Handle errors
                        print("FIDO Authentication failed: \(error.localizedDescription)")
                        // Optionally: show an alert to the user here
                    }
                }
            }) {
                Text("Authenticate with FIDO")
            }
        }
    }
}
