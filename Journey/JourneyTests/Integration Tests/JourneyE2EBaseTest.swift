//
//  JourneyE2EBaseTest.swift
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingLogger

open class JourneyE2EBaseTest: XCTestCase {
    private(set) var config: Config!
    var configFileName = "Config"
    
    open var defaultJourney: Journey!
    open var username: String!
    open var userFirstName: String!
    open var userLastName: String!
    open var password: String!
    
    open var serverUrl: String!
    open var realm: String!
    open var cookie: String!
    
    open var clientId: String!
    open var scopes: [String]!
    open var redirectUri: String!
    open var discoveryEndpoint: String!
    
    open override func setUp() async throws {
        // Load config or fail
        config = try XCTUnwrap(
            try? Config(configFileName),
            "Failed to load test configuration file: \(configFileName)"
        )
        
        // Fail fast if any required property is missing
        username = try XCTUnwrap(config.username, "Missing 'username' in config")
        userFirstName = try XCTUnwrap(config.userFname, "Missing 'userFname' in config")
        userLastName = try XCTUnwrap(config.userLname, "Missing 'userLname' in config")
        password = try XCTUnwrap(config.password, "Missing 'password' in config")
        
        serverUrl = try XCTUnwrap(config.serverUrl, "Missing 'serverUrl' in config")
        realm = try XCTUnwrap(config.realm, "Missing 'realm' in config")
        cookie = try XCTUnwrap(config.cookieName, "Missing 'cookieName' in config")
        
        discoveryEndpoint = try XCTUnwrap(config.discoveryEndpoint, "Missing 'discoveryEndpoint' in config")
        clientId = try XCTUnwrap(config.clientId, "Missing 'clientId' in config")
        scopes = try XCTUnwrap(config.scopes, "Missing 'scopes' in config")
        redirectUri = try XCTUnwrap(config.redirectUri, "Missing 'redirectUri' in config")
                
        
        defaultJourney = Journey.createJourney { config in
            config.timeout = 30
            config.logger = LogManager.standard
            config.serverUrl = self.serverUrl
            config.realm = self.realm
            config.cookie = self.cookie
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.discoveryEndpoint = self.discoveryEndpoint
                oidcValue.clientId = self.clientId
                oidcValue.scopes = Set(self.scopes)
                oidcValue.redirectUri = self.redirectUri
            }
        }
        
        // Start with a clean session
        await defaultJourney?.journeyUser()?.logout()
    }
    
    open override func tearDown() async throws {
        try await super.tearDown()
        await defaultJourney?.journeyUser()?.logout()
    }
    
    @discardableResult
    func handleLoginCallbacks(journey: Journey? = nil, treeName: String? = nil) async throws -> Node {
        let activeJourney = journey ?? defaultJourney!
        let treeName = treeName ?? "Login"
        let node = await activeJourney.start(treeName)
        
        guard let continueNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode but got \(type(of: node))")
            throw XCTSkip("Login step failed")
        }
        
        guard let usernameCallback = continueNode.callbacks.first as? NameCallback,
              let passwordCallback = continueNode.callbacks.last as? PasswordCallback else {
            XCTFail("Missing expected Name and Password callbacks")
            throw XCTSkip("Callbacks missing")
        }
        
        usernameCallback.name = username
        passwordCallback.password = password
        
        return await continueNode.next()
    }
}

