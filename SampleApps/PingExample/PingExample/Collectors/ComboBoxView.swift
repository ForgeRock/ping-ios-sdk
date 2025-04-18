//
//  ComboBoxView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci

struct ComboBoxView: View {
    let field: MultiSelectCollector
    var onNodeUpdated: () -> Void
    
    @EnvironmentObject var validationViewModel: ValidationViewModel
    @State private var expanded: Bool = false
    @State private var selectedOptions: [String] = []
    @State private var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.required ? "\(field.label)*" : field.label)
                .font(.headline)
                .padding(.bottom, 4)
            Menu {
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
                            Text(option.label)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } label: {
                HStack {
                    Text(selectedOptions.isEmpty ? "Select options" : selectedOptions.joined(separator: ", "))
                        .foregroundColor(selectedOptions.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(Color.themeButtonBackground)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
                )
            }
            if !isValid {
                ErrorMessageView(errors: field.validate().map { $0.errorMessage }.sorted())
            }
        }
        .padding()
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
