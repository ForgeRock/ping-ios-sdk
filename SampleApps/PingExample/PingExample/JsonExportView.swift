// 
//  JsonExportView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// Reusable view for displaying and exporting JSON data.
struct JsonExportView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let jsonData: String
    
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text(jsonData)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.systemGroupedBackground))
                
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = jsonData
                        copied = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy to Clipboard")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.themeButtonBackground)
                        .cornerRadius(12)
                    }
                    .disabled(copied)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Reusable export button component.
struct ExportButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export as JSON")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themeButtonBackground)
            .cornerRadius(12)
        }
    }
}
