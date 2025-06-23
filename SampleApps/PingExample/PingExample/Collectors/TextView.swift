//
//  TextView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci
import PingJourney

struct TextView: View {
    let field: TextCollector
    let onNodeUpdated: () -> Void
    
    @EnvironmentObject var validationViewModel: ValidationViewModel
    @State var text: String = ""
    @State private var isValid: Bool = true
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    field.required ? "\(field.label)*" : field.label,
                    text: $text
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
                )
                .onAppear(perform: {
                    text = field.value
                })
                .onChange(of: text) { newValue in
                    field.value = newValue
                    isValid = field.validate().isEmpty
                    onNodeUpdated()
                }
                if !isValid {
                    ErrorMessageView(errors: field.validate().map { $0.errorMessage }.sorted())
                }
            }
        }
        .onChange(of: validationViewModel.shouldValidate) { newValue in
            if newValue {
                isValid = field.validate().isEmpty
            }
        }
        .padding()
    }
}

struct NameCallbackView: View {
    let field: NameCallback
    let onNodeUpdated: () -> Void
    
    @State var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                field.prompt,
                text: $text
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .onAppear(perform: {
                text = field.name
            })
            .onChange(of: text) { newValue in
                field.name = newValue // update internal state only
            }
            .onSubmit {
                onNodeUpdated() // commit to node state only when done
            }
            .padding()
        }
    }
}
