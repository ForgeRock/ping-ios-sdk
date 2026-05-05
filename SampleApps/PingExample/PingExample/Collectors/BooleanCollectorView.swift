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
        VStack(alignment: .leading, spacing: 8) {
            if field.appearance == .switch {
                switchAppearance
            } else {
                checkboxAppearance
            }
            if !isValid {
                ErrorMessageView(errors: field.validate().map { $0.errorMessage }.sorted())
            }
        }
        .padding(.horizontal, 16)
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
                    .foregroundStyle(isChecked ? Color.themeButtonBackground : Color.gray)
            }
            .buttonStyle(PlainButtonStyle())
            labelContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
        )
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
        )
    }
    
    // MARK: - Label Content
    
    @ViewBuilder
    private var labelContent: some View {
        if let richContent = field.richContent {
            richTextView(richContent: richContent)
        } else {
            Text(field.required ? "\(field.label)*" : field.label)
        }
    }
    
    // MARK: - Rich Content Rendering
    
    private func richTextView(richContent: RichContent) -> some View {
        let attributedString = buildAttributedString(from: richContent)
        return Text(attributedString)
    }
    
    private func buildAttributedString(from richContent: RichContent) -> AttributedString {
        let template = richContent.content
        var result = AttributedString()
        
        // Split the template on {{...}} patterns and build attributed string segments
        var remaining = template[template.startIndex...]
        
        while let openRange = remaining.range(of: "{{") {
            // Add text before the placeholder
            let prefix = String(remaining[remaining.startIndex..<openRange.lowerBound])
            result.append(AttributedString(prefix))
            
            let afterOpen = openRange.upperBound
            guard let closeRange = remaining[afterOpen...].range(of: "}}") else {
                // No closing braces found, append the rest as-is
                result.append(AttributedString(String(remaining[openRange.lowerBound...])))
                remaining = remaining[remaining.endIndex...]
                break
            }
            
            let placeholderKey = String(remaining[afterOpen..<closeRange.lowerBound])
            
            if let replacement = richContent.replacements[placeholderKey] {
                if replacement.type == "link", let href = replacement.href, let url = URL(string: href) {
                    var linkText = AttributedString(replacement.value)
                    linkText.link = url
                    linkText.foregroundColor = Color.themeButtonBackground
                    result.append(linkText)
                } else {
                    result.append(AttributedString(replacement.value))
                }
            } else {
                // Unknown placeholder, keep original
                result.append(AttributedString("{{\(placeholderKey)}}"))
            }
            
            remaining = remaining[closeRange.upperBound...]
        }
        
        // Append any remaining text after the last placeholder
        if !remaining.isEmpty {
            result.append(AttributedString(String(remaining)))
        }
        
        return result
    }
    
    // MARK: - Helpers
    
    private func toggleValue() {
        isChecked.toggle()
        field.value = isChecked
        isValid = field.validate().isEmpty
        onNodeUpdated()
    }
}
