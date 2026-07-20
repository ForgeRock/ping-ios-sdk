//
//  JsonConfigPreviewView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct JsonConfigPreviewView: View {
    let config: Configuration
    @Environment(\.dismiss) private var dismiss

    private var jsonContent: String {
        guard let filename = config.jsonFileName else { return "" }
        let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Configs"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let text = String(data: pretty, encoding: .utf8)
        else { return "Unable to load file." }
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(jsonContent)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
