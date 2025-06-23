//
//  ConfigurationManager.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import SwiftUI
import UIKit
import PingOidc


//The ConfigurationManager class is used to manage the configuration settings for the SDK.
//The class provides the following functionality:
//   - Load the current configuration
//   - Save the current configuration
//   - Delete the saved configuration
//   - Provide the default configuration
//   - Start the SDK with the current configuration

class ConfigurationManager: ObservableObject, @unchecked Sendable {
    static let shared = ConfigurationManager()
    public var currentConfigurationViewModel: ConfigurationViewModel?
    
    public var journeyUser: User? {
        get async {
            let journeyUser = await journey.user()
            return journeyUser
        }
    }
    
    public var davinciUser: User? {
        get async {
            let davinciUser = await davinci.user()
            return davinciUser
        }
    }
    
    public func loadConfigurationViewModel() -> ConfigurationViewModel {
        if self.currentConfigurationViewModel == nil {
            self.currentConfigurationViewModel = defaultConfigurationViewModel()
        }
        return self.currentConfigurationViewModel!
    }
    
    /// Save the current configuration
    public func saveConfiguration() {
        if let currentConfiguration = self.currentConfigurationViewModel {
            let encoder = JSONEncoder()
            let configuration = Configuration(clientId: currentConfiguration.clientId, scopes: currentConfiguration.scopes, redirectUri: currentConfiguration.redirectUri, signOutUri: currentConfiguration.signOutUri, discoveryEndpoint: currentConfiguration.discoveryEndpoint, environment: currentConfiguration.environment, cookieName: currentConfiguration.cookieName, serverUrl: currentConfiguration.serverUrl, realm: currentConfiguration.realm)
            if let encoded = try? encoder.encode(configuration) {
                let defaults = UserDefaults.standard
                defaults.set(encoded, forKey: "CurrentConfiguration")
            }
        }
    }
    
    /// Delete the saved configuration
    public func deleteSavedConfiguration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "CurrentConfiguration")
    }
    
    /// Provide the default configuration. If empty or not found, provide the placeholder configuration
    public func defaultConfigurationViewModel() -> ConfigurationViewModel {
        let defaults = UserDefaults.standard
        if let savedConfiguration = defaults.object(forKey: "CurrentConfiguration") as? Data {
            let decoder = JSONDecoder()
            if let loadedConfiguration = try? decoder.decode(Configuration.self, from: savedConfiguration) {
                return ConfigurationViewModel(clientId: loadedConfiguration.clientId, scopes: loadedConfiguration.scopes, redirectUri: loadedConfiguration.redirectUri, signOutUri: loadedConfiguration.signOutUri, discoveryEndpoint: loadedConfiguration.discoveryEndpoint, environment: loadedConfiguration.environment, cookieName: loadedConfiguration.cookieName, serverUrl: loadedConfiguration.serverUrl, realm: loadedConfiguration.realm)
            }
        }
        
        //TODO: Provide here the Server configuration. Add the PingOne server Discovery Endpoint and the OAuth2.0 client details. Or the AIC server URL and Realm, server Discovery Endpoint and the OAuth2.0 client details.
//        return ConfigurationViewModel(
//            clientId: "021b83ce-a9b1-4ad4-8c1d-79e576eeab76",
//            scopes: ["openid", "email", "address", "phone", "profile"], // Alter the scopes based on your clients configuration
//            redirectUri: "org.forgerock.demo://oauth2redirect",
//            signOutUri: "org.forgerock.demo://oauth2redirect",
//            discoveryEndpoint: "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration",
//            environment: "PingOne",
//            cookieName: nil
//        )
        
        return ConfigurationViewModel(
            clientId: "iosClient",
            scopes: ["openid", "email", "address"], // Alter the scopes based on your clients configuration
            redirectUri: "frauth://com.forgerock.ios.frexample",
            signOutUri: "",
            discoveryEndpoint: "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/.well-known/openid-configuration",
            environment: "AIC",
            cookieName: "386c0d288cac4b9",
            serverUrl: "https://openam-bafaloukas.forgeblocks.com/am",
            realm: "alpha"
        )
    }
}

//Extensions
extension ObservableObject {
    @MainActor
    var topViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topController = keyWindow.rootViewController else {
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}

extension Binding {
    func toUnwrapped<T: Sendable>(defaultValue: T) -> Binding<T> where Value == Optional<T>  {
        Binding<T>(get: { self.wrappedValue ?? defaultValue }, set: { self.wrappedValue = $0 })
    }
}
