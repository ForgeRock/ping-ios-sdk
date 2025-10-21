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
            
            // 1. Button action now creates a Task
            Button(action: {
                Task {
                    do {
                        // 2. Get the window (same as before)
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = windowScene.windows.first else {
                            print("Could not find active window scene.")
                            return // Exit if no window found
                        }
                        
                        // 3. Use 'try await' to call the async version
                        _ = try await collector.authenticate(window: window) // Result is returned, but we might not need it here if state is updated internally
                        
                        // 4. Handle success by calling onNext()
                        onNext()
                        
                    } catch {
                        // 5. Handle errors in the catch block
                        print("FIDO Authentication failed: \(error.localizedDescription)")
                    }
                }
            }) {
                Text("Authenticate with FIDO")
            }
        }
    }
}
