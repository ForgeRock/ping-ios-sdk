//
//  CheckBoxView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci

struct CheckBoxView: View {
    var field: MultiSelectCollector
    var onNodeUpdated: () -> Void
    
    @EnvironmentObject var validationViewModel: ValidationViewModel
    @State private var selectedOptions: [String] = []
    @State private var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.required ? "\(field.label)*" : field.label)
                .font(.headline)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(field.options, id: \.value) { option in
                    let isSelected = selectedOptions.contains(option.value)
                    
                    Button(action: {
                        if isSelected {
                            selectedOptions.removeAll { $0 == option.value }
                            field.value.removeAll { $0 == option.value }
                        } else {
                            selectedOptions.append(option.value)
                            field.value.append(option.value)
                        }
                        isValid = field.validate().isEmpty
                        onNodeUpdated()
                    }) {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isSelected ? Color.themeButtonBackground : Color.gray)
                            Text(option.label)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
            )
            if !isValid {
                ErrorMessageView(errors: field.validate().map { $0.errorMessage }.sorted())
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            selectedOptions = field.value.sorted()
        }
        .onChange(of: validationViewModel.shouldValidate) { newValue in
            if newValue {
                isValid = field.validate().isEmpty
            }
        }
    }
}
