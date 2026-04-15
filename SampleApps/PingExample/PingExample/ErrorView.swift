//
//  ErrorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci
import PingOrchestrate

/// A reusable error card view with a title and message in red text.
struct ErrorView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(.systemRed))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemRed))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.08))
        )
    }
}


struct ErrorNodeView: View {
    let node: ErrorNode
    @State private var showDetails: Bool = false
    
    private var errorText: String {
        var error = ""
        
        for detail in node.details {
            if let details = detail.rawResponse.details {
                for detail in details {
                    error += "\(String(describing: detail.message))\n\n"
                    
                    if let innerError = detail.innerError {
                        for (key, value) in innerError.errors {
                            error += "\(key): \(value)\n\n"
                        }
                    }
                }
                
            }
        }
        
        return error
    }
    
    var body: some View {
        ErrorView(title: "Error", message: node.message)
            .onTapGesture {
                showDetails = true
            }
            .alert("Error Details", isPresented: $showDetails) {
                Button("OK") {
                    showDetails = false
                }
            } message: {
                Text(errorText)
            }
    }
}
