//
//  ConfigurationListView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct ConfigurationListView: View {
    @ObservedObject private var configManager = ConfigurationManager.shared
    @State private var editingConfig: Configuration?
    @State private var showEditor = false
    @State private var configToDelete: Configuration?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(ConfigType.allCases, id: \.self) { type in
                    let configs = configManager.configurations.filter { $0.type == type }
                    configSection(type: type, configs: configs)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Configurations")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ConfigurationEditorView()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .alert("Delete Configuration", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let config = configToDelete {
                    withAnimation {
                        configManager.deleteConfiguration(config)
                    }
                }
            }
        } message: {
            if let config = configToDelete {
                Text("Are you sure you want to delete \"\(config.name)\"?")
            }
        }
    }
    
    private func configSection(type: ConfigType, configs: [Configuration]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(type.rawValue.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            if configs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("No configurations")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Tap + to add one")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(configs.enumerated()), id: \.element.name) { index, config in
                        configRow(config)
                        
                        if index < configs.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private func configRow(_ config: Configuration) -> some View {
        let isSelected = configManager.selections[config.type]?.name == config.name
        let host = URL(string: config.discoveryEndpoint).flatMap { $0.host } ?? config.discoveryEndpoint
        
        return HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configManager.select(config)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .themeButtonBackground : Color(.tertiaryLabel))
            }
            .buttonStyle(PlainButtonStyle())
            
            if config.isDefault {
                configRowContent(config: config, host: host)
            } else {
                NavigationLink {
                    ConfigurationEditorView(editing: config)
                } label: {
                    configRowContent(config: config, host: host)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                duplicateConfiguration(config)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            if !config.isDefault {
                Button(role: .destructive) {
                    configToDelete = config
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private func configRowContent(config: Configuration, host: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: config.type.icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(host)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(config.clientId)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !config.isDefault {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
    }
    
    private func duplicateConfiguration(_ config: Configuration) {
        var baseName = config.name + " (Copy)"
        var counter = 2
        while configManager.configurations.contains(where: { $0.name == baseName }) {
            baseName = config.name + " (Copy \(counter))"
            counter += 1
        }
        let duplicate = Configuration(
            name: baseName,
            type: config.type,
            clientId: config.clientId,
            scopes: config.scopes,
            redirectUri: config.redirectUri,
            signOutUri: config.signOutUri,
            discoveryEndpoint: config.discoveryEndpoint,
            environment: config.environment,
            cookieName: config.cookieName,
            serverUrl: config.serverUrl,
            realm: config.realm,
            acrValues: config.acrValues
        )
        withAnimation {
            configManager.addConfiguration(duplicate)
        }
    }
}

private extension ConfigType {
    var icon: String {
        switch self {
        case .journey: return "map.fill"
        case .davinci: return "key.fill"
        case .oidcWeb: return "lock.shield.fill"
        case .device: return "tv"
        }
    }
}
