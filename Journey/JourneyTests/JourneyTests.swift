//
//  JourneyTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
import PingJourneyPlugin
@testable import PingJourney
@testable import PingLogger
@testable import PingOrchestrate
@testable import PingStorage
@testable import PingOidc

class JourneyBaseTests: XCTestCase, @unchecked Sendable {
    var config: Config = Config()
    var configFileName: String = ""
    
    override func setUp() {
        super.setUp()
        if self.configFileName.count > 0 {
            do {
                self.config = try Config(self.configFileName)
            }
            catch {
                XCTFail("Failed to load test configuration file: \(error)")
            }
        }
    }
    
    override func setUp() async throws {
        try await super.setUp()
        if self.configFileName.count > 0 {
            do {
                self.config = try Config(self.configFileName)
            }
            catch {
                XCTFail("Failed to load test configuration file: \(error)")
            }
        }
    }
}


final class JourneyTests: JourneyBaseTests, @unchecked Sendable {
    
    var journey: Journey?
    
    override func setUp() {
        self.configFileName = "Config"
        super.setUp()
        
        self.journey = Journey.createJourney { config in
            config.logger = LogManager.standard
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
        
        MockURLProtocol.startInterceptingRequests()
        _ = CallbackRegistry.shared
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
                //            case MockAPIEndpoint.token.url.path:
                //                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenResponse)
                //            case MockAPIEndpoint.userinfo.url.path:
                //                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.userinfoResponse)
                //            case MockAPIEndpoint.revocation.url.path:
                //                return (HTTPURLResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
                //            case MockAPIEndpoint.endSession.url.path:
                //                return (HTTPURLResponse(url: MockAPIEndpoint.endSession.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
                //            case MockAPIEndpoint.authorization.url.path:
                //                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testJourney() throws {
        guard let journey = self.journey else {
            XCTFail("Failed to create Journey instance")
            return
        }
        
        XCTAssertEqual(journey.config.modules.count, 4)
        XCTAssertEqual(journey.initHandlers.count, 2)
        XCTAssertEqual(journey.nextHandlers.count, 2)
        //        XCTAssertEqual(journey.nodeHandlers.count, 1)
        //        XCTAssertEqual(journey.responseHandlers.count, 1)
        XCTAssertEqual(journey.signOffHandlers.count, 2)
        XCTAssertEqual(journey.successHandlers.count, 2)
        
        let nosession = Module.of { setup in
            setup.next { ( context,connector, request) in
                request.header(name: "nosession", value: "true")
                return request
            }
        }
        
        let journey1 = Journey.createJourney { config in
            config.logger = LogManager.standard
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
            config.module(nosession)
        }
        
        XCTAssertEqual(journey1.config.modules.count, 5)
        XCTAssertEqual(journey1.initHandlers.count, 2)
        XCTAssertEqual(journey1.nextHandlers.count, 3)
        XCTAssertEqual(journey1.nodeHandlers.count, 0)
        XCTAssertEqual(journey1.responseHandlers.count, 0)
        XCTAssertEqual(journey1.signOffHandlers.count, 2)
        XCTAssertEqual(journey1.successHandlers.count, 2)
    }
    
    func testJourneyModuleRegistration() {
        let journey = Journey.createJourney { journeyConfig in
            journeyConfig.logger = LogManager.standard
            journeyConfig.serverUrl = self.config.serverUrl
            journeyConfig.realm = self.config.realm
            journeyConfig.cookie = self.config.cookieName
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
        XCTAssertEqual(journey.config.modules.count, 4)
    }
    
    func testJourneyHandlerCounts() {
        let journey = Journey.createJourney { config in
            config.logger = LogManager.standard
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
        XCTAssertEqual(journey.initHandlers.count, 2)
        XCTAssertEqual(journey.nextHandlers.count, 2)
        XCTAssertEqual(journey.signOffHandlers.count, 2)
        XCTAssertEqual(journey.successHandlers.count, 2)
    }
    
    func testJourneyWithAdditionalModule() {
        let nosession = Module.of { setup in
            setup.next { (context, connector, request) in
                request.header(name: "nosession", value: "true")
                return request
            }
        }
        let journey = Journey.createJourney { config in
            config.logger = LogManager.standard
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
            config.module(nosession)
        }
        XCTAssertEqual(journey.config.modules.count, 5)
        XCTAssertEqual(journey.nextHandlers.count, 3)
    }
    
    // MARK: - Custom Session Storage Tests
    
    func testJourneyWithCustomSessionStorage() async throws {
        // Create a Journey instance with custom session storage
        let customJourney = Journey.createJourney { journeyConfig in
            journeyConfig.logger = LogManager.standard
            journeyConfig.serverUrl = self.config.serverUrl
            journeyConfig.realm = self.config.realm
            journeyConfig.cookie = self.config.cookieName
            
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                
                // Configure custom token storage
                oidcValue.storage = KeychainStorage<Token>(account: "test_custom_tokens")
            }
        }
        
        // Initialize the journey to trigger the setup.initialize handlers
        try await customJourney.initialize()
        
        // After initialization, the SessionModule's initialize handler has run
        // and the SessionConfig should be set in shared context
        let sessionConfig = customJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig
        XCTAssertNotNil(sessionConfig, "Session config should be set in shared context")
        XCTAssertNotNil(sessionConfig?.storage, "Session storage should be configured")
        
        // Now customize the storage for this specific test
        if let sessionConfig = sessionConfig {
            sessionConfig.storage = KeychainStorage<SSOTokenImpl>(
                account: "test_custom_session",
                encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
            )
        }
        
        // Verify the Journey instance was created successfully
        XCTAssertNotNil(customJourney)
        XCTAssertEqual(customJourney.config.modules.count, 4)
    }
    
    func testMultipleJourneyInstancesWithIsolatedStorage() async throws {
        // Create User A Journey instance
        let userAJourney = Journey.createJourney { journeyConfig in
            journeyConfig.logger = LogManager.standard
            journeyConfig.serverUrl = self.config.serverUrl
            journeyConfig.realm = self.config.realm
            journeyConfig.cookie = self.config.cookieName
            
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = KeychainStorage<Token>(account: "user_a_tokens")
            }
        }
        
        // Initialize User A's journey
        try await userAJourney.initialize()
        
        // Customize User A's session storage after initialization
        if let userASessionConfig = userAJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig {
            userASessionConfig.storage = KeychainStorage<SSOTokenImpl>(
                account: "user_a_sessions",
                encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
            )
        }
        
        // Create User B Journey instance
        let userBJourney = Journey.createJourney { journeyConfig in
            journeyConfig.logger = LogManager.standard
            journeyConfig.serverUrl = self.config.serverUrl
            journeyConfig.realm = self.config.realm
            journeyConfig.cookie = self.config.cookieName
            
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = KeychainStorage<Token>(account: "user_b_tokens")
            }
        }
        
        // Initialize User B's journey
        try await userBJourney.initialize()
        
        // Customize User B's session storage after initialization
        if let userBSessionConfig = userBJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig {
            userBSessionConfig.storage = KeychainStorage<SSOTokenImpl>(
                account: "user_b_sessions",
                encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
            )
        }
        
        // Verify both instances are created successfully
        XCTAssertNotNil(userAJourney)
        XCTAssertNotNil(userBJourney)
        
        // Verify they have different storage configurations
        let userASessionConfig = userAJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig
        let userBSessionConfig = userBJourney.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig
        
        XCTAssertNotNil(userASessionConfig, "User A session config should exist")
        XCTAssertNotNil(userBSessionConfig, "User B session config should exist")
        
        // Each Journey instance should have its own SessionConfig
        // Since SessionModule.config is added by default in createJourney(), each Journey gets its own instance
        XCTAssertTrue(userASessionConfig !== userBSessionConfig, "Session configs should be different instances")
    }
    
    func testSessionStorageIsolation() async throws {
        // Create a custom storage for testing
        let storage = KeychainStorage<SSOTokenImpl>(
            account: "test_storage_isolation",
            encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
        )
        
        // Create a mock SSOToken
        let mockToken = SSOTokenImpl(
            value: "test_session_value",
            successUrl: "https://example.com/success",
            realm: "test_realm"
        )
        
        // Save the token
        try await storage.save(item: mockToken)
        
        // Retrieve the token
        let retrievedToken = try await storage.get()
        
        // Verify the token was saved and retrieved correctly
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken?.value, "test_session_value")
        XCTAssertEqual(retrievedToken?.successUrl, "https://example.com/success")
        XCTAssertEqual(retrievedToken?.realm, "test_realm")
        
        // Clean up
        try await storage.delete()
        
        // Verify deletion
        let deletedToken = try? await storage.get()
        XCTAssertNil(deletedToken, "Token should be nil after deletion")
    }
    
    func testSSOTokenImplCodable() throws {
        // Create a mock SSOToken
        let originalToken = SSOTokenImpl(
            value: "test_token_value",
            successUrl: "https://example.com/success",
            realm: "alpha"
        )
        
        // Encode the token
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalToken)
        XCTAssertFalse(encodedData.isEmpty, "Encoded data should not be empty")
        
        // Decode the token
        let decoder = JSONDecoder()
        let decodedToken = try decoder.decode(SSOTokenImpl.self, from: encodedData)
        
        // Verify the decoded token matches the original
        XCTAssertEqual(decodedToken.value, originalToken.value)
        XCTAssertEqual(decodedToken.successUrl, originalToken.successUrl)
        XCTAssertEqual(decodedToken.realm, originalToken.realm)
    }
    
    func testSessionConfigConvenienceInitializer() {
        // Test the convenience initializer
        let sessionConfig = SessionConfig(account: "test_convenience_account")
        
        XCTAssertNotNil(sessionConfig.storage)
        
        // The storage should be configured with a custom account
        // We can't directly verify the account name, but we can verify the storage exists
        XCTAssertNotNil(sessionConfig.storage, "Storage should be initialized with custom account")
    }
}

