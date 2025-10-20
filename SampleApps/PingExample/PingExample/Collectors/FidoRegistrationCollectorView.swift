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
                    collector.register(window: window) { result in
                        switch result {
                        case .success:
                            onNext()
                        case .failure(let error):
                            print("FIDO Registration failed: \(error.localizedDescription)")
                        }
                    }
                }
            }) {
                Text("Register with FIDO")
            }
        }
    }
}
