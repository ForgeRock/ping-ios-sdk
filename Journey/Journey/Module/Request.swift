//
//  Journey.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// The Request module is responsible for initiating the authentication journey.
/// It sets the URL for the authentication request and includes any necessary parameters.

import Foundation
import PingOrchestrate

extension Request {
    /// Initializes a request to the authentication endpoint with the provided parameters.
    /// - Parameters:
    ///   - authIndexValue: The value for the authentication index, typically a service name.
    ///   - authIndexType: The type of the authentication index, defaulting to "service".
    ///   - journeyConfig: The configuration for the journey, including server URL and realm.
    /// - Returns: A configured request ready to be sent.
    internal func populateRequest(
        authIndexValue: String,
        authIndexType: String = "service",
        journeyConfig: JourneyConfig
    ) {
        let authenticateEndpoint = "\(journeyConfig.serverUrl ?? "")/json/realms/\(journeyConfig.realm)/authenticate"
        self.url(authenticateEndpoint)
        self.header(name: JourneyConstants.acceptApiVersion, value: JourneyConstants.resource21Protocol10)
        self.header(name: JourneyConstants.contentType, value: JourneyConstants.applicationJson)
        if !authIndexType.isEmpty {
            self.parameter(name: JourneyConstants.authIndexType, value: authIndexType)
        }
        if !authIndexValue.isEmpty {
            self.parameter(name: JourneyConstants.authIndexValue, value: authIndexValue)
        }
        if journeyConfig.forceAuth {
            self.parameter(name: "ForceAuth", value: "true")
        }
        if journeyConfig.noSession {
            self.parameter(name: "noSession", value: "true")
        }
        self.body(body: [String: Any]())
    }
}
