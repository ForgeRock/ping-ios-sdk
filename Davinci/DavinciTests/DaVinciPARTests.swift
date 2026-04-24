//
//  DaVinciPARTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingDavinciPlugin
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci
@testable import PingNetwork

final class DaVinciPARTests: XCTestCase, @unchecked Sendable {
    
    /// Helper to read httpBodyStream data from URLRequest (httpBody is nil when using URLSession with URLProtocol)
    private func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return data
    }
    
    let testClientId = "test"
    let testScopes = ["openid", "email", "address"]
    let testRedirectUri = "http://localhost:8080"
    let testDiscoveryEndpoint = "http://localhost/.well-known/openid-configuration"
    
    /// Creates an `HTTPURLResponse` or throws, replacing force-unwrap (`!`) in mock handlers.
    private func mockResponse(url: URL, statusCode: Int, headers: [String: String]? = nil) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers) else {
            throw URLError(.badServerResponse)
        }
        return response
    }
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
        _ = CollectorFactory.shared
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    // MARK: - PAR Happy Path
    
    func testDaVinciPARHappyPath() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), MockResponse.openIdConfigurationWithPARResponse)
            case MockAPIEndpoint.par.url.path:
                return (try mockResponse(url: MockAPIEndpoint.par.url, statusCode: 201, headers: MockResponse.headers), MockResponse.parResponse)
            case MockAPIEndpoint.token.url.path:
                return (try mockResponse(url: MockAPIEndpoint.token.url, statusCode: 200, headers: MockResponse.headers), MockResponse.tokenResponse)
            case MockAPIEndpoint.userinfo.url.path:
                return (try mockResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, headers: MockResponse.headers), MockResponse.userinfoResponse)
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (try mockResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 200, headers: MockResponse.customHTMLTemplateHeaders), MockResponse.customHTMLTemplate)
            case MockAPIEndpoint.authorization.url.path:
                return (try mockResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, headers: MockResponse.authorizeResponseHeaders), MockResponse.authorizeResponse)
            default:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = MockURLProtocol.makeClient()
            
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
                oidcValue.par = true
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode, "Expected ContinueNode, got \(type(of: node))")
        
        // Verify request sequence: [0]=discovery, [1]=PAR POST, [2]=authorize
        XCTAssertGreaterThanOrEqual(MockURLProtocol.requestHistory.count, 3)
        
        // Verify PAR request
        let parRequest = MockURLProtocol.requestHistory[1]
        XCTAssertEqual(parRequest.url!.path, "/par")
        XCTAssertEqual(parRequest.httpMethod, "POST")
        
        // Verify PAR POST body contains expected OIDC params
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("client_id=test"), "PAR body should contain client_id")
        XCTAssertTrue(parBody.contains("response_type=code"), "PAR body should contain response_type")
        XCTAssertTrue(parBody.contains("code_challenge="), "PAR body should contain code_challenge")
        XCTAssertTrue(parBody.contains("code_challenge_method=S256"), "PAR body should contain code_challenge_method")
        XCTAssertTrue(parBody.contains("response_mode=pi.flow"), "PAR body should contain response_mode")
        
        // Verify authorize request uses request_uri
        let authorizeReq = MockURLProtocol.requestHistory[2]
        XCTAssertTrue(authorizeReq.url!.query?.contains("request_uri=") ?? false, "Authorize URL should contain request_uri")
        XCTAssertTrue(authorizeReq.url!.query?.contains("client_id=test") ?? false, "Authorize URL should contain client_id")
        XCTAssertTrue(authorizeReq.url!.query?.contains("response_mode=pi.flow") ?? false, "Authorize URL should contain response_mode")
        
        // Verify authorize URL does NOT contain full OIDC params
        XCTAssertFalse(authorizeReq.url!.query?.contains("code_challenge=") ?? true, "Authorize URL should NOT contain code_challenge when PAR is used")
        XCTAssertFalse(authorizeReq.url!.query?.contains("response_type=") ?? true, "Authorize URL should NOT contain response_type when PAR is used")
        
        // Complete the flow
        let continueNode = node as! ContinueNode
        (continueNode.collectors[0] as? TextCollector)?.value = "My First Name"
        (continueNode.collectors[1] as? PasswordCollector)?.value = "My Password"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")
        
        let successNode = node as! SuccessNode
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
        case .failure(_):
            XCTFail("Should have succeeded")
        }
    }
    
    // MARK: - PAR Disabled (Standard Flow)
    
    func testDaVinciWithoutPAR() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), MockResponse.openIdConfigurationWithPARResponse)
            case MockAPIEndpoint.token.url.path:
                return (try mockResponse(url: MockAPIEndpoint.token.url, statusCode: 200, headers: MockResponse.headers), MockResponse.tokenResponse)
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (try mockResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 200, headers: MockResponse.customHTMLTemplateHeaders), MockResponse.customHTMLTemplate)
            case MockAPIEndpoint.authorization.url.path:
                return (try mockResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, headers: MockResponse.authorizeResponseHeaders), MockResponse.authorizeResponse)
            default:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = MockURLProtocol.makeClient()
            
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
                // par is false by default
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode, "Expected ContinueNode, got \(type(of: node))")
        
        // Verify request sequence: [0]=discovery, [1]=authorize (NO PAR request)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2)
        
        // Verify authorize request has full OIDC params (standard flow)
        let authorizeReq = MockURLProtocol.requestHistory[1]
        XCTAssertTrue(authorizeReq.url!.query?.contains("client_id=test") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("response_mode=pi.flow") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge=") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge_method=S256") ?? false)
        XCTAssertFalse(authorizeReq.url!.query?.contains("request_uri=") ?? true, "Standard flow should NOT use request_uri")
        
        // Complete the flow
        let continueNode = node as! ContinueNode
        (continueNode.collectors[0] as? TextCollector)?.value = "My First Name"
        (continueNode.collectors[1] as? PasswordCollector)?.value = "My Password"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")
    }
    
    // MARK: - PAR with Additional OIDC Parameters
    
    func testDaVinciPARWithAdditionalOidcParameters() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), MockResponse.openIdConfigurationWithPARResponse)
            case MockAPIEndpoint.par.url.path:
                return (try mockResponse(url: MockAPIEndpoint.par.url, statusCode: 201, headers: MockResponse.headers), MockResponse.parResponse)
            case MockAPIEndpoint.token.url.path:
                return (try mockResponse(url: MockAPIEndpoint.token.url, statusCode: 200, headers: MockResponse.headers), MockResponse.tokenResponse)
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (try mockResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 200, headers: MockResponse.customHTMLTemplateHeaders), MockResponse.customHTMLTemplate)
            case MockAPIEndpoint.authorization.url.path:
                return (try mockResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, headers: MockResponse.authorizeResponseHeaders), MockResponse.authorizeResponse)
            default:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = MockURLProtocol.makeClient()
            
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
                oidcValue.par = true
                oidcValue.acrValues = "acrValues"
                oidcValue.loginHint = "login_hint"
                oidcValue.nonce = "nonce"
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode, "Expected ContinueNode, got \(type(of: node))")
        
        // Verify PAR POST body contains additional OIDC params
        let parRequest = MockURLProtocol.requestHistory[1]
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("acr_values=acrValues"), "PAR body should contain acr_values")
        XCTAssertTrue(parBody.contains("login_hint=login_hint"), "PAR body should contain login_hint")
        XCTAssertTrue(parBody.contains("nonce=nonce"), "PAR body should contain nonce")
        
        // Verify authorize URL does NOT contain these params
        let authorizeReq = MockURLProtocol.requestHistory[2]
        XCTAssertFalse(authorizeReq.url!.query?.contains("acr_values=") ?? true, "Authorize URL should NOT contain acr_values when PAR is used")
        XCTAssertFalse(authorizeReq.url!.query?.contains("login_hint=") ?? true, "Authorize URL should NOT contain login_hint when PAR is used")
        XCTAssertFalse(authorizeReq.url!.query?.contains("nonce=") ?? true, "Authorize URL should NOT contain nonce when PAR is used")
    }
}
