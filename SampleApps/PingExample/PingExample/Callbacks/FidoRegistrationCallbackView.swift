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
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    callback.register(deviceName: deviceName, window: window) { error in
                        if let error = error {
                            print("FIDO Registration failed: \(error.localizedDescription)")
                        }
                        onNext()
                    }
                }
            }) {
                Text("Register with FIDO")
            }
        }
    }
}
