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
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            if field.titleEnabled && !field.title.isEmpty {
                Text(field.title)
                    .pingSectionHeader()
            }

            ScrollView {
                Text(field.content)
                    .pingCaptionText()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(PingTheme.Spacing.small)
            .overlay(
                RoundedRectangle(cornerRadius: PingTheme.Shape.fieldRadius)
                    .stroke(PingTheme.Color.separator, lineWidth: PingTheme.Shape.borderWidth)
            )
        }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
