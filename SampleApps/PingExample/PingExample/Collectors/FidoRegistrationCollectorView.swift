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
    
    // Note: The async version of `register` in the collector doesn't take deviceName.
    // If you need deviceName functionality with the async version, you'll need to modify
    // the FidoRegistrationCollector's async `register` method to accept it.
    // For now, this @State is unused with the async call as defined previously.
    @State private var deviceName: String = ""
    
    var body: some View {
        VStack {
            Text("FIDO Registration")
                .font(.title)
            
            // This TextField remains, but isn't used by the async call below
            TextField("Device Name (Optional)", text: $deviceName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            // 1. Button action now creates a Task
            Button(action: {
                Task {
                    do {
                        // 2. Get the window
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = windowScene.windows.first else {
                            print("Could not find active window scene.")
                            return // Exit if no window found
                        }
                        
                        // 3. Use 'try await' to call the async version
                        // Note: Passing deviceName would require modifying the async 'register'
                        _ = try await collector.register(window: window)
                        
                        // 4. Handle success by calling onNext()
                        onNext()
                        
                    } catch {
                        // 5. Handle errors in the catch block
                        print("FIDO Registration failed: \(error.localizedDescription)")
                        // Optionally: show an alert to the user here
                    }
                }
            }) {
                Text("Register with FIDO")
            }
        }
    }
}
