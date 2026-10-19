//
//  UserInfoView.swift
//  PingExample
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// A view that displays user information across Journey, DaVinci, and OIDC tabs
struct UserInfoView: View {
    let menuItem: MenuItem
    @StateObject private var userInfoViewModel = UserInfoViewModel()
    @State private var selectedTab: AuthTab = .journey

    var body: some View {
        VStack(spacing: 0) {
            TabPicker(selection: $selectedTab, label: \.rawValue, icon: \.icon)

            let result = userInfoViewModel.results[selectedTab] ?? UserInfoResult()

            if result.isLoading {
                Spacer()
                PingLoadingSpinner()
                Spacer()
            } else if let error = result.error {
                ErrorView(title: "\(selectedTab.rawValue) Error", message: error)
                    .padding(.top, PingTheme.Spacing.small)
                Spacer()
            } else {
                ScrollView {
                    userInfoCard(result.info)
                        .pingScrollContentPadding(top: PingTheme.Spacing.small, bottom: 0)
                }
            }
        }
        .pingScreenBackground()
        .navigationTitle(menuItem.title)
        .navigationBarTitleDisplayMode(.inline)
    }


    private func userInfoCard(_ info: String) -> some View {
        let pairs = parseUserInfo(info)
        return VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            HStack {
                Image(systemName: selectedTab.icon)
                    .foregroundStyle(PingTheme.Color.actionPrimary)
                Text("\(selectedTab.rawValue) User Info")
                    .pingSectionHeader()
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                ForEach(pairs, id: \.key) { pair in
                    PingInfoRow(
                        label: pair.key,
                        value: pair.value,
                        layout: .vertical,
                        valueStyle: .monospaced
                    )
                }
            }
        }
        .pingCardStyle()
    }

    private func parseUserInfo(_ info: String) -> [UserInfoPair] {
        info.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return UserInfoPair(key: String(parts[0]).trimmingCharacters(in: .whitespaces),
                                value: String(parts[1]).trimmingCharacters(in: .whitespaces))
        }
    }
}

private struct UserInfoPair: Identifiable {
    let key: String
    let value: String
    var id: String { key }
}
