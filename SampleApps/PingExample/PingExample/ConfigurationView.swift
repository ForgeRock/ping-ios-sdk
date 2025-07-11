//
//  ConfigurationView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct ConfigurationView: View {
    @Binding var configurationViewModel: ConfigurationViewModel
    @State private var scopes: String = ""
    @State private var environments = ["AIC", "PingOne"]
    @State private var selectedEnvironment = "AIC"
    
    var body: some View {
        Form {
            Section(header: Text("Selected Environment")) {
                Section {
                    Text("Selected Environment (AIC or PingOne):")
                    TextField("Selected Environment", text: $configurationViewModel.environment)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
            }
            Section(header: Text("AIC Server details")) {
                Section {
                    Text("Server URL:")
                    TextField("Server URL", text: $configurationViewModel.serverUrl.toUnwrapped(defaultValue: ""))
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Realm name:")
                    TextField("Realm name", text: $configurationViewModel.realm.toUnwrapped(defaultValue: ""))
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Cookie name:")
                    TextField("Cookie name", text: $configurationViewModel.cookieName.toUnwrapped(defaultValue: ""))
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
            }
            Section(header: Text("OAuth 2.0 details")) {
                Section {
                    Text("Client Id:")
                    TextField("Client Id", text: $configurationViewModel.clientId)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Redirect URI:")
                    TextField("Redirect URI", text: $configurationViewModel.redirectUri)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("SignOut URI:")
                    TextField("SignOut URI", text: $configurationViewModel.signOutUri.toUnwrapped(defaultValue: ""))
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Discovery Endpoint:")
                    TextField("Discovery Endpoint", text: $configurationViewModel.discoveryEndpoint)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Scopes:")
                    TextField("scopes:", text: $scopes)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
            }
            Section(header: Text("Browser Configuration")) {
                Button(action: {
                    Task {
                        configurationViewModel.scopes = scopes.components(separatedBy: " ")
                        configurationViewModel.saveConfiguration()
                    }
                }) {
                    Text("Save Configuration")
                }
                Button(action: {
                    Task {
                        let defaultConfiguration = configurationViewModel.resetConfiguration()
                        configurationViewModel = defaultConfiguration
                        scopes = $configurationViewModel.scopes.wrappedValue.joined(separator: " ")
                    }
                }) {
                    Text("Reset Configuration")
                }
            }
        }
        .navigationTitle("Edit Configuration")
        .onAppear{
            scopes = $configurationViewModel.scopes.wrappedValue.joined(separator: " ")
            selectedEnvironment = configurationViewModel.environment
        }
        .onDisappear{
            configurationViewModel.scopes = scopes.components(separatedBy: " ")
            configurationViewModel.saveConfiguration()
        }
    }
}
