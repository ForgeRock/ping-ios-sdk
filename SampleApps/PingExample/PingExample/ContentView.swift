//
//  ContentView.swift
//  PingExample
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingExternalIdPFacebook
import PingExternalIdPGoogle
/// The main application entry point.
@main
struct MyApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    let handled = GoogleRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
                    if !handled {
                        FacebookRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
                    }
                }
        }
    }
}

/// The main view of the application, displaying navigation options and a logo.
struct ContentView: View {
    /// State variable to track if Davinci has started.
    @State private var startDavinci = false
    /// State variable for managing the navigation stack path.
    @State private var path: [String] = []
    /// State variable for managing the configuration view model.
    @State private var configurationViewModel: ConfigurationViewModel = ConfigurationManager.shared.loadConfigurationViewModel()
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink(value: "Configuration") {
                    Text("Edit configuration")
                }
                NavigationLink(value: "DaVinci") {
                    Text("Launch DaVinci")
                }
                NavigationLink(value: "Journey") {
                    Text("Launch Journey")
                }
                NavigationLink(value: "Token") {
                    Text("Access Token")
                }
                NavigationLink(value: "User") {
                    Text("User Info")
                }
                NavigationLink(value: "Logout") {
                    Text("Logout")
                }
                NavigationLink(value: "Logger") {
                    Text("Logger")
                }
                NavigationLink(value: "Storage") {
                    Text("Storage")
                }
            }.navigationDestination(for: String.self) { item in
                switch item {
                case "Configuration":
                    ConfigurationView(configurationViewModel: $configurationViewModel)
                case "DaVinci":
                    DavinciView(path: $path)
                case "Journey":
                    JourneyView(path: $path)
                case "Token":
                    AccessTokenView(accessTokenViewModel: AccessTokenViewModel())
                case "User":
                    UserInfoView()
                case "Logout":
                    LogOutView(path: $path)
                case "Logger":
                    LoggerView()
                case "Storage":
                    StorageView()
                default:
                    EmptyView()
                }
            }.navigationBarTitle("Ping SDK")
                .accentColor(.themeButtonBackground)
            Spacer()
            Image("Logo").resizable().scaledToFill().frame(width: 100, height: 100)
                .padding(.vertical, 32)
        }
    }
}
