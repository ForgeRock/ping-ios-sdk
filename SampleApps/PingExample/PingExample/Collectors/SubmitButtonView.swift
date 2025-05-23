// 
//  SubmitButtonView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci

struct SubmitButtonView: View {
    var field: SubmitCollector
    let onNext: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                field.value = "submit"
                onNext(true)
            } label: {
                Text(field.label)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                    .background(Color.themeButtonBackground)
                    .cornerRadius(15.0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
