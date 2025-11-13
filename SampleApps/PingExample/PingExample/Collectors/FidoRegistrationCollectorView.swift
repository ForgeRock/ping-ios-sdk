//
//  FidoRegistrationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido

struct FidoRegistrationCollectorView: View {
    var collector: FidoRegistrationCollector
    let onNext: () -> Void
    
    // Note: The async Result version of `register` currently doesn't accept deviceName.
    // If needed, modify the collector's async method.
    @State private var deviceName: String = ""
    
    var body: some View {
        VStack {
            Text("FIDO Registration")
                .font(.title)
            
            // TextField remains, but isn't used by the async call below
            TextField("Device Name (Optional)", text: $deviceName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            // 1. Button action still creates a Task
            Button(action: {
                Task {
                    // 2. Get the window
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else {
                        print("Could not find active window scene.")
                        return // Exit if no window found
                    }
                    
                    // 3. Call the async function and await its Result
                    //    Note: Not passing deviceName here
                    let result = await collector.register(window: window)
                    
                    // 4. Handle the Result
                    switch result {
                    case .success(let attestationValue):
                        // Optional: Use attestationValue if needed
                        print("FIDO Registration successful: \(attestationValue)")
                        // Call onNext only on success
                        onNext()
                    case .failure(let error):
                        // Handle errors
                        print("FIDO Registration failed: \(error.localizedDescription)")
                        // Optionally: show an alert to the user here
                    }
                }
            }) {
                if collector.label.isEmpty {
                    Text("Register with FIDO")
                } else {
                    Text(collector.label)
                }
            }
        }
    }
}
