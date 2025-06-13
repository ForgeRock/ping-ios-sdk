//
//  DaVinciErrorTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate
@testable import PingStorage
@testable import PingLogger
@testable import PingOidc
@testable import PingDavinci

class DaVinciErrorTests: DaVinciBaseTests, @unchecked Sendable {
    
    override func setUp() {
        super.setUp()
        
        self.config.clientId = "test"
        self.config.scopes = ["openid", "email", "address"]
        self.config.redirectUri = "http://localhost:8080"
        self.config.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        
        MockURLProtocol.startInterceptingRequests()
        _ = CollectorFactory()
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testDaVinciWellKnownEndpointFailedwith404() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 404, httpVersion: nil, headerFields: MockResponse.headers)!, "Not Found".data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let error = (node as! FailureNode).cause as! OidcError
        
        switch error {
        case .apiError(let code, _):
            XCTAssertEqual(code, 404)
        default:
            XCTFail()
        }
        
    }
    
    func testDaVinciAuthorizeEndpointFailedWith401() async throws {
        let number = Int.random(in: 400 ..< 500)
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": 1999,
                    "message": "Unauthorized!",
                    "errorMessage": "Unauthorized!",
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, _):
            XCTAssertTrue(code == number)
        }
    }
    
    func testDaVinciInvalidSessionBetween400To499() async throws {
        let number = Int.random(in: 400 ..< 500)
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "connectorId": "pingOneAuthenticationConnector",
                    "capabilityName": "setSession",
                    "message": "Invalid Connector.",
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, _):
            XCTAssertTrue(code == number)
        }
    }
    
    func testDaVinciInvalidConnectorBetween400To499() async throws {
        let number = Int.random(in: 400 ..< 500)
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "connectorId": "pingOneAuthenticationConnector",
                    "capabilityName": "returnSuccessResponseRedirect",
                    "message": "Invalid Connector.",
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, _):
            XCTAssertTrue(code == number)
        }
    }
    
    func testDaVinciTimeOutBetween400To499() async throws {
        let number = Int.random(in: 400 ..< 500)
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": "requestTimedOut",
                    "message": "Request timed out. Please try again.",
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, _):
            XCTAssertTrue(code == number)
        }
    }
    
    
    func testDaVinciAuthorizeEndpointFailedBetween400To499() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": "INVALID_REQUEST",
                    "message": "Invalid DV Flow Policy ID: Single_Factor"
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ErrorNode)
        let errorNode = node as! ErrorNode
        XCTAssertTrue(errorNode.input.description.contains("INVALID_REQUEST"))
    }
    
    func testDaVinciAuthorizeEndpointFailedWith500() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, """
              {
                  "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                  "code": "INVALID_REQUEST",
                  "message": "Invalid DV Flow Policy ID: Single_Factor"
              }
              """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, _):
            XCTAssertTrue(code == 500)
        }
        
    }
    
    func testDaVinciAuthorizeEndpointFailedWithOKResponseButFailedStatusDuringTransform() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "environment": {
                        "id": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae"
                    },
                    "status": "FAILED",
                    "error": {
                        "code": "login_required",
                        "message": "The request could not be completed. There was an issue processing the request"
                    }
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let error = (node as! FailureNode).cause as! ApiError
        
        switch error {
        case .error( _, _, let message):
            XCTAssertTrue(message.contains("login_required"))
        }
        
    }
    
    func testDaVinciAuthorizeEndpointFailedWithOKResponseButErrorDuringTransform() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, """
              {
                  "environment": {
                      "id": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae"
                  },
                  "error": {
                      "code": "login_required",
                      "message": "The request could not be completed. There was an issue processing the request"
                  }
              }
              """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let error = (node as! FailureNode).cause as! ApiError
        
        switch error {
        case .error( _, _, let message):
            XCTAssertTrue(message.contains("login_required"))
        }
        
    }
    
    func testDaVinciTransformFailed() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, " Not a Json ".data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
    }
    
    func testDaVinciInvalidPassword() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.customHTMLTemplateHeaders)!, MockResponse.customHTMLTemplateWithInvalidPassword)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node =  await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let connector = node as! ContinueNode
        if let textCollector = connector.collectors[0] as? TextCollector {
            textCollector.value = "My First Name"
        }
        if let passwordCollector = connector.collectors[1] as? PasswordCollector {
            passwordCollector.value = "My Password"
        }
        if let submitCollector = connector.collectors[2] as? SubmitCollector {
            submitCollector.value = "click me"
        }
        
        let next = await connector.next()
        
        XCTAssertEqual((connector.collectors[1] as? PasswordCollector)?.value, "")
        
        XCTAssertTrue(next is ErrorNode)
        let errorNode = next as! ErrorNode
        XCTAssertTrue(errorNode.continueNode === connector)
        XCTAssertEqual(errorNode.message, "Invalid username and/or password")
        XCTAssertTrue(errorNode.input.description.contains("The provided password did not match provisioned password"))
    }
    
    func testDaVinci3xxErrorWithLocationHeaderInResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                var headers = MockResponse.authorizeResponseHeaders
                headers["Location"] = "https://apps.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/signon/?error=test"
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 302, httpVersion: nil, headerFields: headers)!, " ".data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        let apiError = failureNode.cause as! ApiError
        switch apiError {
        case .error(let code, _, let message):
            XCTAssertEqual(message, "Location: https://apps.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/signon/?error=test")
            XCTAssertTrue(code == 302)
        }
    }
    
    
    func testDaVinciPasswordPolicyFailed() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.passwordValidationError)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ErrorNode)
        let errorNode = node as! ErrorNode
        
        let details = errorNode.details
        XCTAssertEqual(details.count, 1)
        
        let detail = details[0]
        // Validate rawResponse
        XCTAssertEqual(detail.rawResponse.id, "ffbab117-06e6-44be-a17a-ae619d3d7334")
        XCTAssertEqual(detail.rawResponse.code, "INVALID_DATA")
        XCTAssertEqual(detail.rawResponse.message, "The request could not be completed. One or more validation errors were in the request.")
        
        // Validate details
        XCTAssertEqual(detail.rawResponse.details?.count, 1)
        let errorDetail = detail.rawResponse.details?[0]
        XCTAssertEqual(errorDetail?.code, "INVALID_VALUE")
        XCTAssertEqual(errorDetail?.target, "password")
        XCTAssertEqual(errorDetail?.message, "User password did not satisfy password policy requirements")
        
        // Validate inner errors
        XCTAssertEqual(errorDetail?.innerError?.errors.count, 5)
        let errors = errorDetail?.innerError?.errors
        
        XCTAssertEqual(
            errors?["minCharacters"],
            "The provided password did not contain enough characters from the character set 'ZYXWVUTSRQPONMLKJIHGFEDCBA'.  The minimum number of characters from that set that must be present in user passwords is 1"
        )
        
        XCTAssertEqual(
            errors?["excludesCommonlyUsed"],
            "The provided password (or a variant of that password) was found in a list of prohibited passwords"
        )
        
        XCTAssertEqual(
            errors?["length"],
            "The provided password is shorter than the minimum required length of 8 characters"
        )
        
        XCTAssertEqual(
            errors?["maxRepeatedCharacters"],
            "The provided password is not acceptable because it contains a character repeated more than 2 times in a row"
        )
        
        XCTAssertEqual(
            errors?["minUniqueCharacters"],
            "The provided password does not contain enough unique characters.  The minimum number of unique characters that may appear in a user password is 5"
        )
        
        XCTAssertEqual(detail.statusCode, 400)
    }
}
