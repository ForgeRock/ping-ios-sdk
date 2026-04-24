//
//  ConfigurationEditorView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: 20) {
                // MARK: - Identity
                editorSection {
                    labeledField("Name *", text: $name, field: .name)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type *")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack(spacing: 0) {
                            ForEach(ConfigType.allCases, id: \.self) { t in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { type = t }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: t.iconName)
                                            .font(.system(size: 11))
                                        Text(t.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(type == t ? Color.themeButtonBackground : Color.clear)
                                    .foregroundColor(type == t ? .white : .primary)
                                    .cornerRadius(7)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(2)
                        .background(Color(.systemGray5))
                        .cornerRadius(9)
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
                editorSection(header: "OAUTH / OIDC") {
                    labeledField("Client ID *", text: $clientId, field: .clientId)
                    labeledField("Scopes", text: $scopes, field: .scopes, placeholder: "openid, email, profile")
                    labeledField("Redirect URI *", text: $redirectUri, field: .redirectUri, keyboard: .URL)
                    
                    if type == .davinci {
                        labeledField("Sign Out URI", text: $signOutUri, field: .signOutUri, keyboard: .URL)
                    }
                    
                    labeledField("Discovery Endpoint *", text: $discoveryEndpoint, field: .discoveryEndpoint, keyboard: .URL)
                }
                
                // MARK: - Journey-specific
                if type == .journey {
                    editorSection(header: "JOURNEY") {
                        labeledField("Server URL *", text: $serverUrl, field: .serverUrl, keyboard: .URL)
                        labeledField("Cookie Name", text: $cookieName, field: .cookieName)
                        labeledField("Realm", text: $realm, field: .realm, placeholder: "alpha")
                    }
                }
                
                // MARK: - Advanced
                editorSection(header: "ADVANCED") {
                    labeledField("ACR Values", text: $acrValues, field: .acrValues)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $par) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PAR (Pushed Authorization Request)")
                                    .font(.system(size: 14, weight: .medium))
                                Text("RFC 9126 — Push authorization parameters to the server before authorization")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
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
                .font(.system(size: 16, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 0) {
            if let header = header {
                Text(header)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(keyboard)
                .padding(10)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
