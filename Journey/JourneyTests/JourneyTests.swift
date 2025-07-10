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
@testable import PingJourney
@testable import PingLogger
@testable import PingOidc
@testable import PingOrchestrate

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
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
        
        MockURLProtocol.startInterceptingRequests()
        _ = CallbackRegistry()
        
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
            config.module(OidcModule.config) { oidcValue in
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
        let journey = Journey.createJourney { config in
            config.logger = LogManager.standard
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(OidcModule.config) { oidcValue in
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
            config.module(OidcModule.config) { oidcValue in
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
            config.module(OidcModule.config) { oidcValue in
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
}
