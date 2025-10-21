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
                // 1. Create a Task to handle async code
                Task {
                    do {
                        // 2. Get the window
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = windowScene.windows.first else {
                            print("Could not find active window scene.")
                            return
                        }
                        
                        // 3. Use 'try await' to call the async function
                        try await callback.authenticate(window: window)
                        
                        // 4. Handle success by calling onNext()
                        onNext()
                        
                    } catch {
                        // 5. Handle errors in the catch block
                        print("FIDO Authentication failed: \(error.localizedDescription)")
                        onNext()
                    }
                }
            }) {
                Text("Authenticate with FIDO")
            }
        }
    }
}
