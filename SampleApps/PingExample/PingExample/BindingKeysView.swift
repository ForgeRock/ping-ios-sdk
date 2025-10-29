//
//  BindingKeysView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingBinding

struct BindingKeysView: View {
    @StateObject private var viewModel = BindingKeysViewModel()
    
    var body: some View {
        VStack {
            if viewModel.userKeys.isEmpty {
                Text("No Binding Keys Found")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(viewModel.userKeys) { key in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User ID: \(key.userId)")
                                .font(.headline)
                            Text("Key Tag: \(key.keyTag)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Auth Type: \(key.authType.rawValue)")
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Binding Keys")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Delete All", role: .destructive) {
                    viewModel.deleteAllKeys()
                }
                .disabled(viewModel.userKeys.isEmpty)
            }
        }
        .onAppear {
            viewModel.fetchKeys()
        }
    }
    
    private func delete(at offsets: IndexSet) {
        offsets.map { viewModel.userKeys[$0] }.forEach(viewModel.deleteKey)
    }
}

struct BindingKeysView_Previews: PreviewProvider {
    static var previews: some View {
        BindingKeysView()
    }
}
