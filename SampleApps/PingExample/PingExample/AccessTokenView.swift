//
//  AccessTokenView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// Displays access token details for Journey, DaVinci, and OIDC (Web) auth flows.
/// Can show all tabs or be locked to a single tab via `fixedTab`.
/// Provides Refresh, Revoke, and Get Token actions.
struct AccessTokenView: View {
    let menuItem: MenuItem
    /// When non-nil, locks the view to a single tab (hides the tab picker).
    let fixedTab: AuthTab?
    @StateObject private var accessTokenViewModel = AccessTokenViewModel()
    @State private var selectedTab: AuthTab = .journey
    
    init(menuItem: MenuItem, fixedTab: AuthTab? = nil) {
        self.menuItem = menuItem
        self.fixedTab = fixedTab
        self._selectedTab = State(initialValue: fixedTab ?? .journey)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if fixedTab == nil {
                TabPicker(selection: $selectedTab, label: \.rawValue, icon: \.icon)
            }
            
            let result = accessTokenViewModel.results[selectedTab] ?? AccessTokenResult()

            if result.isLoading {
                PingTheme.Color.appBackground
                    .overlay(PingLoadingSpinner())
            } else if let error = result.error {
                ErrorView(title: "\(selectedTab.rawValue) Error", message: error)
                    .padding(.top, PingTheme.Spacing.small)
                Spacer()

                if result.hasSession {
                    getTokenBar
                }
            } else {
                ScrollView {
                    accessTokenCard(result.info)
                        .pingScrollContentPadding(top: PingTheme.Spacing.small, bottom: 0)
                }

                tokenActionBar
            }
        }
        .pingScreenBackground()
        .navigationTitle(menuItem.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Vertical padding for the pinned action bars beneath the token card.
    /// No shared token matches this value exactly.
    private let actionBarVerticalPadding: CGFloat = 12

    private var tokenActionBar: some View {
        HStack(spacing: PingTheme.Spacing.medium) {
            Button {
                Task { await accessTokenViewModel.refresh(tab: selectedTab) }
            } label: {
                HStack(spacing: PingTheme.Spacing.small) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.pingPrimary)

            Button {
                Task { await accessTokenViewModel.revoke(tab: selectedTab) }
            } label: {
                HStack(spacing: PingTheme.Spacing.small) {
                    Image(systemName: "xmark.circle")
                    Text("Revoke")
                }
            }
            .buttonStyle(.pingDestructive)
        }
        .padding(.horizontal, PingTheme.Spacing.screen)
        .padding(.vertical, actionBarVerticalPadding)
        .background(PingTheme.Color.groupedSurface)
    }

    private var getTokenBar: some View {
        Button {
            Task { await accessTokenViewModel.getToken(tab: selectedTab) }
        } label: {
            HStack(spacing: PingTheme.Spacing.small) {
                Image(systemName: "key.fill")
                Text("Get Token")
            }
        }
        .buttonStyle(.pingPrimary)
        .padding(.horizontal, PingTheme.Spacing.screen)
        .padding(.vertical, actionBarVerticalPadding)
        .background(PingTheme.Color.groupedSurface)
    }


    private func accessTokenCard(_ info: String) -> some View {
        let pairs = parseTokenInfo(info)
        return VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            HStack {
                Image(systemName: selectedTab.icon)
                    .foregroundStyle(PingTheme.Color.actionPrimary)
                Text("\(selectedTab.rawValue) Access Token")
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
    
    private func parseTokenInfo(_ info: String) -> [AccessTokenPair] {
        info.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return AccessTokenPair(key: String(parts[0]).trimmingCharacters(in: .whitespaces),
                                   value: String(parts[1]).trimmingCharacters(in: .whitespaces))
        }
    }
}

private struct AccessTokenPair: Identifiable {
    let key: String
    let value: String
    var id: String { key }
}
