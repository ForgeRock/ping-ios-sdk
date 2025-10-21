//
//  FidoRegistrationCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoRegistrationCallbackView: View {
    var callback: FidoRegistrationCallback
    let onNext: () -> Void
    
    @State private var deviceName: String = ""
    
    var body: some View {
        VStack {
            Text("FIDO Registration")
                .font(.title)
            TextField("Device Name (Optional)", text: $deviceName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                // 1. Create a Task to handle async code
                Task {
                    do {
                        // 2. Get the window (same as before)
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = windowScene.windows.first else {
                            print("Could not find active window scene.")
                            return
                        }
                        
                        // 3. Use 'try await' to call the async function
                        // We pass nil if the deviceName is empty, otherwise pass the name
                        let name = deviceName.isEmpty ? nil : deviceName
                        try await callback.register(deviceName: name, window: window)
                        
                        // 4. Handle success by calling onNext()
                        onNext()
                        
                    } catch {
                        // 5. Handle errors in the catch block by calling onNext()
                        print("FIDO Registration failed: \(error.localizedDescription)")
                        onNext()
                    }
                }
            }) {
                Text("Register with FIDO") // This text is from your provided code
            }
        }
    }
}
