//
//  ReadOnlyTextView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci

struct ReadOnlyTextView: View {
    var field: ReadOnlyTextCollector
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if field.titleEnabled && !field.title.isEmpty {
                Text(field.title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            ScrollView {
                Text(field.content)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 1)
            )
        }
        .padding(8)
    }
}
