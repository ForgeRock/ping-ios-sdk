// 
//  DeviceInfoView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// Displays collected device profile data in two modes:
/// a styled card-based view grouped by sections (platform, hardware, network, etc.)
/// and a raw pretty-printed JSON view, toggled via a toolbar button.
struct DeviceInfoView: View {
    let menuItem: MenuItem
    @StateObject private var deviceInfoViewModel = DeviceInfoViewModel()
    @State private var viewMode: DeviceInfoViewMode = .styled
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if deviceInfoViewModel.isLoading {
                ProgressView()
            } else if let error = deviceInfoViewModel.error {
                VStack {
                    ErrorView(title: "Device Info Error", message: error)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if viewMode == .raw {
                rawView
            } else {
                styledView
            }
        }
        .navigationTitle(menuItem.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !deviceInfoViewModel.isLoading && deviceInfoViewModel.error == nil {
                    Button {
                        viewMode = viewMode == .styled ? .raw : .styled
                    } label: {
                        Image(systemName: viewMode == .styled ? "curlybraces" : "list.bullet.rectangle")
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .contentTransition(.identity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.none, value: viewMode)
    }
    
    private var styledView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !deviceInfoViewModel.topLevel.isEmpty {
                    sectionCard(icon: "info.circle.fill", title: "Device", entries: deviceInfoViewModel.topLevel)
                }
                
                ForEach(deviceInfoViewModel.sections, id: \.name) { section in
                    sectionCard(icon: sectionIcon(section.name), title: section.name.capitalized, entries: section.entries)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .textSelection(.enabled)
    }
    
    private var rawView: some View {
        ScrollView {
            Text(deviceInfoViewModel.rawJSON)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
        }
    }
    
    private func sectionCard(icon: String, title: String, entries: [(key: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.themeButtonBackground)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries, id: \.key) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.key)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(entry.value)
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
    
    private func sectionIcon(_ name: String) -> String {
        switch name {
        case "platform": return "iphone"
        case "hardware": return "cpu"
        case "network": return "wifi"
        case "telephony": return "phone.fill"
        case "browser": return "safari.fill"
        case "bluetooth": return "wave.3.right"
        case "location": return "location.fill"
        default: return "info.circle.fill"
        }
    }
}

private enum DeviceInfoViewMode {
    case styled, raw
}
