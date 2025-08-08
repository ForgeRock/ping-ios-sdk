// 
//  SelectIdpCallback.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney

/// Represents a single Identity Provider option returned by the server.
public struct IdPValue: Identifiable {
   
    public var id: String { provider }
    /// The unique identifier for the provider (e.g., "google", "apple").
    /// This is the value that should be sent back to the server if selected.
    public let provider: String
    
    /// A dictionary containing UI configuration hints from the server,
    /// such as background color or button icons, to help render the provider's button.
    public let uiConfig: [String: Any]
    
    /// Creates an `IdPValue` instance by parsing a JSON object (dictionary).
    /// - Parameter json: A dictionary representing the provider's JSON data.
    init(from json: [String: Any]) {
        self.provider = json["provider"] as? String ?? ""
        self.uiConfig = json["uiConfig"] as? [String: Any] ?? [:]
    }
}

/// A callback that prompts the user to select one from a list of Identity Providers (IdPs).
///
/// This callback provides a list of `IdPValue` objects, each representing a social
/// or enterprise identity provider. The developer should render a UI to allow the user
/// to make a selection, set the `value` property with the chosen provider's name,
/// and then submit the callback.
public final class SelectIdpCallback: AbstractCallback, @unchecked Sendable {
    
    // MARK: - Public Properties
    
    /// A list of available identity provider options. This property is read-only.
    public private(set) var providers: [IdPValue] = []
    
    /// The value of the provider selected by the user.
    /// You must set this property with the `provider` string from the selected `IdPValue`
    /// before submitting the form.
    public var value: String = ""
    
    // MARK: - Initialization and Parsing
    
    /// Sets the callback's properties from the JSON received from the authentication server.
    /// It specifically parses the list of providers from the "output" part of the JSON.
    /// - Parameters:
    ///  - name: The name of the callback.
    ///  - value: The JSON value containing the list of providers.
    public override func initValue(name: String, value: Any) {
        guard let providersArray = value as? [[String: Any]] else {
            return
        }
        
        // Map the array of JSON objects to our Swift `IdPValue` struct
        self.providers = providersArray.map { IdPValue(from: $0) }
    }
    
    // MARK: - Payload
    
    /// Constructs the final payload with the token received from the IdP.
    /// - Returns: A dictionary containing the selected provider's name.
    public override func payload() -> [String: Any] {
        return input(self.value)
    }
}
