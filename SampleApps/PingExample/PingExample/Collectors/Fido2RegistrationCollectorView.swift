//
//  Fido2RegistrationCollectorView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingFido2

struct Fido2RegistrationCollectorView: View {
    var collector: Fido2RegistrationCollector
    let onNext: () -> Void
    
    @State private var deviceName: String = ""
    
    var body: some View {
        VStack {
            Text("FIDO2 Registration")
                .font(.title)
            TextField("Device Name (Optional)", text: $deviceName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                collector.register { result in
                    switch result {
                    case .success:
                        onNext()
                    case .failure(let error):
                        print("FIDO2 Registration failed: \(error.localizedDescription)")
                    }
                }
            }) {
                Text("Register with FIDO2")
            }
        }
    }
}
