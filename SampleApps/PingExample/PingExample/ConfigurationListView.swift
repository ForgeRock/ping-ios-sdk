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
    @State private var previewingJsonConfig: Configuration?
    
    var body: some View {
        ScrollView {
            VStack(spacing: PingTheme.Spacing.large) {
                ForEach(ConfigType.allCases, id: \.self) { type in
                    let configs = configManager.configurations.filter { $0.type == type }
                    configSection(type: type, configs: configs)
                }
            }
            .pingScrollContentPadding()
        }
        .pingScreenBackground()
        .navigationTitle("Configurations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewingJsonConfig) { config in
            JsonConfigPreviewView(config: config)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ConfigurationEditorView()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: PingTheme.Control.Glyph.small, weight: .semibold))
                }
                .accessibilityLabel("Add Configuration")
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
                .font(PingTheme.Typography.supporting.weight(.semibold))
                .foregroundStyle(PingTheme.Color.contentSecondary)
                .padding(.horizontal, PingTheme.Spacing.medium)
                .padding(.bottom, PingTheme.Spacing.small)

            if configs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: PingTheme.Spacing.small) {
                        Image(systemName: type.icon)
                            .font(.system(size: PingTheme.Control.Glyph.medium))
                            .foregroundColor(PingTheme.Color.contentTertiary)
                        Text("No configurations")
                            .pingSupportingText()
                        Text("Tap + to add one")
                            .font(PingTheme.Typography.caption)
                            .foregroundStyle(PingTheme.Color.contentTertiary)
                    }
                    .padding(.vertical, PingTheme.Spacing.large)
                    Spacer()
                }
                .pingCardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(configs.enumerated()), id: \.element.name) { index, config in
                        configRow(config)

                        if index < configs.count - 1 {
                            Divider()
                                // Approximates the inset under configRowContent's icon tile,
                                // past the leading selection toggle.
                                .padding(.leading, 60)
                        }
                    }
                }
                .pingCardStyle(size: .rowList)
            }
        }
    }

    private func configRow(_ config: Configuration) -> some View {
        let isSelected = configManager.selections[config.type]?.name == config.name
        let host = URL(string: config.discoveryEndpoint).flatMap { $0.host } ?? config.discoveryEndpoint

        return HStack(spacing: PingTheme.Spacing.medium) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configManager.select(config)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: PingTheme.Control.Glyph.medium))
                    .foregroundColor(isSelected ? PingTheme.Color.actionPrimary : PingTheme.Color.contentTertiary)
            }
            .buttonStyle(.plain)
            
            if config.isJsonBased {
                Button {
                    previewingJsonConfig = config
                } label: {
                    configRowContent(config: config, host: host)
                }
                .buttonStyle(.plain)
            } else if config.isDefault {
                configRowContent(config: config, host: host)
            } else {
                NavigationLink {
                    ConfigurationEditorView(editing: config)
                } label: {
                    configRowContent(config: config, host: host)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
        .contentShape(Rectangle())
        .contextMenu {
            if !config.isJsonBased {
                Button {
                    duplicateConfiguration(config)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
            if !config.isDefault && !config.isJsonBased {
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
        HStack(spacing: PingTheme.Spacing.medium) {
            PingIconTile(systemName: config.type.icon, diameter: 40, iconSize: 20)

            VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                HStack(spacing: PingTheme.Spacing.small) {
                    Text(config.name)
                        .font(PingTheme.Typography.body.weight(.medium))
                        .foregroundStyle(PingTheme.Color.contentPrimary)
                    if config.isJsonBased {
                        Text("JSON")
                            .font(PingTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(PingTheme.Color.actionPrimary)
                            .padding(.horizontal, PingTheme.Spacing.xSmall)
                            .padding(.vertical, PingTheme.Spacing.xxSmall)
                            .overlay(
                                Capsule()
                                    .strokeBorder(PingTheme.Color.actionPrimary, lineWidth: PingTheme.Shape.borderWidth)
                            )
                    }
                }
                Text(host)
                    .pingSupportingText()
                Text(config.clientId)
                    .pingSupportingText()
            }

            Spacer()

            if !config.isDefault {
                Image(systemName: "chevron.right")
                    .font(.system(size: PingTheme.Control.Glyph.small, weight: .semibold))
                    .foregroundColor(PingTheme.Color.contentSecondary)
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
