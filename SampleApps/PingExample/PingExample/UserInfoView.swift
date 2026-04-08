// 
//  UserInfoView.swift
//  PingExample
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// A view that displays user information across Journey, DaVinci, and OIDC tabs
struct UserInfoView: View {
    let menuItem: MenuItem
    @StateObject private var userInfoViewModel = UserInfoViewModel()
    @State private var selectedTab: UserInfoTab = .journey
    
    var body: some View {
        VStack(spacing: 0) {
            userInfoTabPicker
            
            let result = userInfoViewModel.results[selectedTab] ?? UserInfoResult()
            
            if result.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = result.error {
                UserInfoErrorView(title: "\(selectedTab.rawValue) Error", message: error)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    userInfoCard(result.info)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(menuItem.title)
    }
    
    private var userInfoTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(UserInfoTab.allCases) { tab in
                    userInfoTabButton(tab)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    private func userInfoTabButton(_ tab: UserInfoTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
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
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func userInfoCard(_ info: String) -> some View {
        let pairs = parseUserInfo(info)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: selectedTab.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.themeButtonBackground)
                Text("\(selectedTab.rawValue) User Info")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(pairs, id: \.key) { pair in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.key)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(pair.value)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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

struct UserInfoErrorView: View {
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
