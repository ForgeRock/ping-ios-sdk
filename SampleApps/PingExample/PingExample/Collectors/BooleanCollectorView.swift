// 
//  BooleanCollectorView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci

struct BooleanCollectorView: View {
    var field: BooleanCollector
    var onNodeUpdated: () -> Void
    
    @EnvironmentObject var validationViewModel: ValidationViewModel
    @State private var isChecked: Bool = false
    @State private var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            if field.appearance == .switch {
                switchAppearance
            } else {
                checkboxAppearance
            }
            if !isValid {
                PingFieldMessages(errorMessages: field.validate().map { $0.errorMessage }.sorted())
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
        .onAppear {
            isChecked = field.value
        }
        .onChange(of: validationViewModel.shouldValidate) { newValue in
            if newValue {
                isValid = field.validate().isEmpty
            }
        }
    }
    
    // MARK: - Checkbox Appearance
    
    private var checkboxAppearance: some View {
        HStack(alignment: .top) {
            Button(action: toggleValue) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? PingTheme.Color.actionPrimary : PingTheme.Color.contentSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            labelContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PingTheme.Control.fieldPadding)
        .padding(.vertical, PingTheme.Spacing.compact)
        .pingOutlinedContainerStyle(showsError: !isValid)
    }

    // MARK: - Switch Appearance

    private var switchAppearance: some View {
        HStack(alignment: .top) {
            Toggle("", isOn: $isChecked)
                .labelsHidden()
                .onChange(of: isChecked) { newValue in
                    field.value = newValue
                    isValid = field.validate().isEmpty
                    onNodeUpdated()
                }
            labelContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PingTheme.Control.fieldPadding)
        .padding(.vertical, PingTheme.Spacing.compact)
        .pingOutlinedContainerStyle(showsError: !isValid)
    }
    
    // MARK: - Label Content
    
    @ViewBuilder
    private var labelContent: some View {
        if let richContent = field.richContent {
            Text(RichTextBuilder.build(from: richContent))
        } else {
            Text(field.required ? "\(field.label)*" : field.label)
        }
    }
    
    // MARK: - Helpers
    
    private func toggleValue() {
        isChecked.toggle()
        field.value = isChecked
        isValid = field.validate().isEmpty
        onNodeUpdated()
    }
}
