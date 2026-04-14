//
//  EmptyStateView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// A reusable empty state view with an icon, title, optional subtitle,
/// and optional action content (e.g. buttons).
struct EmptyStateView<Actions: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let actions: Actions

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            actions
        }
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actions = EmptyView()
    }
}
