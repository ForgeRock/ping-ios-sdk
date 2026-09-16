//
//  ConfigurationEditorView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct ConfigurationEditorView: View {
    @ObservedObject private var configManager = ConfigurationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let editingConfig: Configuration?
    
    @State private var name: String = ""
    @State private var type: ConfigType = .journey
    @State private var clientId: String = ""
    @State private var scopes: String = ""
    @State private var redirectUri: String = ""
    @State private var signOutUri: String = ""
    @State private var discoveryEndpoint: String = ""
    @State private var environment: String = "AIC"
    @State private var cookieName: String = ""
    @State private var serverUrl: String = ""
    @State private var realm: String = ""
    @State private var acrValues: String = ""
    @State private var par: Bool = false
    
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name, clientId, scopes, redirectUri, signOutUri, discoveryEndpoint
        case cookieName, serverUrl, realm, acrValues
    }
    
    init(editing config: Configuration? = nil) {
        self.editingConfig = config
    }
    
    /// Fields relevant for the current type, in order.
    private var orderedFields: [Field] {
        var fields: [Field] = [.name, .clientId, .scopes, .redirectUri]
        if type == .davinci {
            fields.append(.signOutUri)
        }
        fields.append(.discoveryEndpoint)
        if type == .journey {
            fields.append(contentsOf: [.serverUrl, .cookieName, .realm])
        }
        fields.append(.acrValues)
        return fields
    }
    
    private func nextField(after field: Field) -> Field? {
        guard let index = orderedFields.firstIndex(of: field), index + 1 < orderedFields.count else { return nil }
        return orderedFields[index + 1]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: PingTheme.Spacing.large) {
                // MARK: - Identity
                editorSection {
                    labeledField("Name *", text: $name, field: .name, placeholder: "e.g., Alpha Environment")

                    // NOTE: This visually duplicates `TabPicker` (see TabPicker.swift), but
                    // `ConfigType` does not conform to `Identifiable` and `TabPicker`'s own
                    // design-system migration is in flight in parallel, so reuse is deferred
                    // rather than forcing cross-file coordination here.
                    VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                        Text("Type *")
                            .pingSectionHeader()
                        Picker("Type", selection: $type) {
                            ForEach(ConfigType.allCases, id: \.self) { t in
                                Label(t.rawValue, systemImage: t.iconName).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Environment is not currently used by the SDK — commented out for now.
                    // VStack(alignment: .leading, spacing: 6) {
                    //     Text("Environment *")
                    //         .font(.system(size: 12, weight: .medium))
                    //         .foregroundColor(.secondary)
                    //     Picker("", selection: $environment) {
                    //         Text("AIC").tag("AIC")
                    //         Text("PingOne").tag("PingOne")
                    //     }
                    //     .pickerStyle(.segmented)
                    //     .labelsHidden()
                    // }
                }

                // MARK: - OAuth / OIDC
                editorSection(header: "OAuth / OIDC") {
                    labeledField("Client ID *", text: $clientId, field: .clientId, placeholder: "e.g., iosClient")
                    labeledField("Scopes", text: $scopes, field: .scopes, placeholder: "openid, email, profile")
                    labeledField("Redirect URI *", text: $redirectUri, field: .redirectUri, placeholder: "e.g., com.example.app:/redirect", keyboard: .URL)

                    if type == .davinci {
                        labeledField("Sign Out URI", text: $signOutUri, field: .signOutUri, placeholder: "e.g., com.example.app:/signout", keyboard: .URL)
                    }

                    labeledField("Discovery Endpoint *", text: $discoveryEndpoint, field: .discoveryEndpoint, placeholder: "e.g., https://openam-example.forgeblocks.com/am/oauth2/alpha/.well-known/openid-configuration", keyboard: .URL)
                }

                // MARK: - Journey-specific
                if type == .journey {
                    editorSection(header: "Journey") {
                        labeledField("Server URL *", text: $serverUrl, field: .serverUrl, placeholder: "e.g., https://openam-example.forgeblocks.com/am", keyboard: .URL)
                        labeledField("Cookie Name", text: $cookieName, field: .cookieName, placeholder: "e.g., iPlanetDirectoryPro")
                        labeledField("Realm", text: $realm, field: .realm, placeholder: "e.g., alpha")
                    }
                }

                // MARK: - Advanced
                editorSection(header: "Advanced") {
                    labeledField("ACR Values", text: $acrValues, field: .acrValues, placeholder: "e.g., urn:acme:authn:default")

                    VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                        Toggle(isOn: $par) {
                            VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                                Text("PAR (Pushed Authorization Request)")
                                    .pingSectionHeader()
                                Text("RFC 9126 — Push authorization parameters to the server before authorization")
                                    .pingSupportingText()
                            }
                        }
                        .tint(PingTheme.Color.actionPrimary)
                    }
                }
            }
            .pingScrollContentPadding()
        }
        .pingScreenBackground()
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle(editingConfig == nil ? "New Configuration" : "Edit Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                }
                .font(PingTheme.Typography.action)
            }
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .onAppear {
            if let config = editingConfig {
                populateFields(from: config)
            }
        }
    }

    // MARK: - Section Card

    private func editorSection<Content: View>(header: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            if let header = header {
                Text(header)
                    .font(PingTheme.Typography.supporting.weight(.semibold))
                    .foregroundStyle(PingTheme.Color.contentSecondary)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
                content()
            }
        }
    }

    // MARK: - Labeled Field

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        field: Field,
        placeholder: String = "",
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            Text(label)
                .pingSectionHeader()
            TextField(placeholder, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(keyboard)
                .pingTextFieldStyle()
                .focused($focusedField, equals: field)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if focusedField == field {
                            Spacer()
                            if let next = nextField(after: field) {
                                Button("Next") {
                                    focusedField = next
                                }
                            } else {
                                Button("Done") {
                                    focusedField = nil
                                }
                            }
                        }
                    }
                }
        }
    }
    
    // MARK: - Populate / Save
    
    private func populateFields(from config: Configuration) {
        name = config.name
        type = config.type
        clientId = config.clientId
        scopes = config.scopes.joined(separator: ", ")
        redirectUri = config.redirectUri
        signOutUri = config.signOutUri ?? ""
        discoveryEndpoint = config.discoveryEndpoint
        environment = config.environment
        cookieName = config.cookieName ?? ""
        serverUrl = config.serverUrl ?? ""
        realm = config.realm ?? ""
        acrValues = config.acrValues ?? ""
        par = config.par ?? false
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            validationMessage = "Name is required."
            showValidationError = true
            return
        }
        
        guard !clientId.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Client ID is required."
            showValidationError = true
            return
        }
        
        guard !discoveryEndpoint.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Discovery Endpoint is required."
            showValidationError = true
            return
        }
        
        if type == .journey {
            guard !serverUrl.trimmingCharacters(in: .whitespaces).isEmpty else {
                validationMessage = "Server URL is required for Journey."
                showValidationError = true
                return
            }
        }
        
        let isRename = editingConfig != nil && editingConfig!.name != trimmedName
        if editingConfig == nil || isRename {
            if configManager.configurations.contains(where: { $0.name == trimmedName }) {
                validationMessage = "A configuration named \"\(trimmedName)\" already exists."
                showValidationError = true
                return
            }
        }
        
        let scopeList = scopes
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let config = Configuration(
            name: trimmedName,
            type: type,
            clientId: clientId.trimmingCharacters(in: .whitespaces),
            scopes: scopeList.isEmpty ? ["openid"] : scopeList,
            redirectUri: redirectUri.trimmingCharacters(in: .whitespaces),
            signOutUri: signOutUri.isEmpty ? nil : signOutUri.trimmingCharacters(in: .whitespaces),
            discoveryEndpoint: discoveryEndpoint.trimmingCharacters(in: .whitespaces),
            environment: environment,
            cookieName: cookieName.isEmpty ? nil : cookieName.trimmingCharacters(in: .whitespaces),
            serverUrl: serverUrl.isEmpty ? nil : serverUrl.trimmingCharacters(in: .whitespaces),
            realm: realm.isEmpty ? nil : realm.trimmingCharacters(in: .whitespaces),
            acrValues: acrValues.isEmpty ? nil : acrValues.trimmingCharacters(in: .whitespaces),
            par: par
        )
        
        if let existing = editingConfig {
            configManager.updateConfiguration(oldName: existing.name, with: config)
        } else {
            configManager.addConfiguration(config)
        }
        
        dismiss()
    }
}
