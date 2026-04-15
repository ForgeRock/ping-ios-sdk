//
//  TabPicker.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// A reusable horizontal pill-style tab picker.
/// Generic over any tab type that conforms to `Hashable`, `CaseIterable`, and `Identifiable`.
struct TabPicker<Tab: Hashable & CaseIterable & Identifiable>: View
where Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    let label: (Tab) -> String
    let icon: (Tab) -> String
    var onSelect: ((Tab) -> Void)? = nil
    var isDisabled: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Tab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selection = tab
            onSelect?(tab)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon(tab))
                    .font(.system(size: 14))
                Text(label(tab))
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selection == tab
                    ? LinearGradient(
                        colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .foregroundColor(selection == tab ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}
