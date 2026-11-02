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
import PingOidc

/// Displays access token details for Journey, DaVinci, and OIDC (Web) auth flows.
/// Can show all tabs or be locked to a single tab via `fixedTab`.
/// Provides Refresh, Revoke, and Get Token actions.
struct AccessTokenView: View {
    let menuItem: MenuItem
    /// When non-nil, locks the view to a single tab (hides the tab picker).
    let fixedTab: AuthTab?
    @StateObject private var accessTokenViewModel = AccessTokenViewModel()
    @State private var selectedTab: AuthTab = .journey
    
    /// - Parameters:
    ///   - fixedTab: Locks the view to one tab and hides the tab picker.
    ///   - initialTab: The tab to open on when the picker is visible.
    init(menuItem: MenuItem, fixedTab: AuthTab? = nil, initialTab: AuthTab? = nil) {
        self.menuItem = menuItem
        self.fixedTab = fixedTab
        self._selectedTab = State(initialValue: fixedTab ?? initialTab ?? .journey)
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

                    if selectedTab == .oidc || selectedTab == .oidcRar || selectedTab == .journey || selectedTab == .davinci {
                        authorizationDetailsCard(result.authorizationDetails)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
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
    
    /// RFC 9396: renders the granted `authorization_details` echoed by the server, one card
    /// per object. Hidden entirely when the server granted none (non-RAR apps see no change).
    @ViewBuilder
    private func authorizationDetailsCard(_ details: [AuthorizationDetail]?) -> some View {
        if let details, !details.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PingTheme.Color.actionPrimary)
                    Text("Granted Authorization Details")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                Divider()

                ForEach(Array(details.enumerated()), id: \.offset) { index, detail in
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow("Type", detail.type)
                        if let locations = detail.locations { detailRow("Locations", locations) }
                        if let actions = detail.actions { detailRow("Actions", actions) }
                        if let datatypes = detail.datatypes { detailRow("Datatypes", datatypes) }
                        if let privileges = detail.privileges { detailRow("Privileges", privileges) }
                        if !detail.additionalFields.isEmpty {
                            Text("Additional fields")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            ForEach(Array(detail.additionalFields.keys).sorted(), id: \.self) { key in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(prettyValue(detail.additionalFields[key]))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        if details.count > 1 && index < details.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private func detailRow(_ label: String, _ values: [String]) -> some View {
        detailRow(label, values.joined(separator: ", "))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }

    /// Pretty-prints an `AuthorizationDetailValue` (objects/arrays pretty-printed via JSONEncoder).
    private func prettyValue(_ value: AuthorizationDetailValue?) -> String {
        guard let value else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        if let data = try? encoder.encode(value),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(describing: value)
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
