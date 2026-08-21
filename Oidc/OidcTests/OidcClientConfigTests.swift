//
//  OidcClientConfigTests.swift
//  OidcTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage

final class OidcClientConfigTests: XCTestCase {
    
    var oidcClientConfig: OidcClientConfig!
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        oidcClientConfig = nil
        MockURLProtocol.stopInterceptingRequests()
        super.tearDown()
    }
    
    // TestRailCase(22106)
    func testDefaultInitialization() {
        oidcClientConfig = OidcClientConfig()
        
        XCTAssertNil(oidcClientConfig.openId)
        XCTAssertEqual(oidcClientConfig.refreshThreshold, 0)
        XCTAssertNil(oidcClientConfig.agent)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "")
        XCTAssertEqual(oidcClientConfig.clientId, "")
        XCTAssertTrue(oidcClientConfig.scopes.isEmpty)
        XCTAssertEqual(oidcClientConfig.redirectUri, "")
        XCTAssertNil(oidcClientConfig.loginHint)
        XCTAssertNil(oidcClientConfig.state)
        XCTAssertNil(oidcClientConfig.nonce)
        XCTAssertNil(oidcClientConfig.display)
        XCTAssertNil(oidcClientConfig.prompt)
        XCTAssertNil(oidcClientConfig.uiLocales)
        XCTAssertNil(oidcClientConfig.acrValues)
        XCTAssertTrue(oidcClientConfig.additionalParameters.isEmpty)
        XCTAssertFalse(oidcClientConfig.par)
        XCTAssertNil(oidcClientConfig.httpClient)
    }
    
    func testUpdateAgent() {
        let agent = MockAgent()
        oidcClientConfig.updateAgent(agent)
        XCTAssertNotNil(oidcClientConfig.agent)
    }
    
    // TestRailCase(22118)
    func testScopeInsertion() {
        oidcClientConfig.scope("openid")
        XCTAssertTrue(oidcClientConfig.scopes.contains("openid"))
    }
    
    // TestRailCase(22118)
    func testOidcInitializeInvalidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.error)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
        } catch {
            XCTAssertNotNil(error)
        }
        XCTAssertNil(oidcClientConfig.openId)
    }
    
    // TestRailCase(24720)
    func testOidcInitializeValidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
            XCTAssertNotNil(oidcClientConfig.openId)
            XCTAssertEqual(MockAPIEndpoint.authorization.url.absoluteString, oidcClientConfig.openId!.authorizationEndpoint)
            XCTAssertEqual(MockAPIEndpoint.token.url.absoluteString, oidcClientConfig.openId!.tokenEndpoint)
            XCTAssertEqual(MockAPIEndpoint.userinfo.url.absoluteString, oidcClientConfig.openId!.userinfoEndpoint)
            XCTAssertEqual(MockAPIEndpoint.endSession.url.absoluteString, oidcClientConfig.openId!.endSessionEndpoint)
            XCTAssertEqual(MockAPIEndpoint.revocation.url.absoluteString, oidcClientConfig.openId!.revocationEndpoint)
        } catch {
            XCTFail("Initialization failed with error: \(error)")
        }
    }
    
    // MARK: - Pre-supplied openId / openIdOverride

    /// Builds a complete `OpenIdConfiguration` pointing at the mock endpoints.
    private func makeOpenIdConfiguration() -> OpenIdConfiguration {
        OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString
        )
    }

    /// A pre-supplied `openId` makes `oidcInitialize()` skip discovery entirely — it succeeds
    /// with no `discoveryEndpoint` configured and issues no network request.
    func testOidcInitializeWithPreSuppliedOpenIdSkipsDiscovery() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected when openId is pre-supplied")
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        oidcClientConfig.discoveryEndpoint = ""
        let supplied = makeOpenIdConfiguration()
        oidcClientConfig.openId = supplied

        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(oidcClientConfig.openId?.authorizationEndpoint, supplied.authorizationEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, supplied.tokenEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, supplied.userinfoEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.endSessionEndpoint, supplied.endSessionEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.revocationEndpoint, supplied.revocationEndpoint)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "Discovery must not be requested when openId is pre-supplied")
    }

    /// `openIdOverride` patches a pre-supplied document, and does so exactly once even though
    /// every `OidcClient` entry point re-enters `oidcInitialize()`.
    func testOpenIdOverrideAppliedOnceToPreSuppliedOpenId() async throws {
        MockURLProtocol.requestHistory.removeAll()
        oidcClientConfig.discoveryEndpoint = ""
        oidcClientConfig.openId = makeOpenIdConfiguration()

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.deviceAuthorizationEndpoint = MockAPIEndpoint.deviceAuthorization.url.absoluteString
        }

        try await oidcClientConfig.oidcInitialize()
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "openIdOverride must be applied exactly once")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, MockAPIEndpoint.deviceAuthorization.url.absoluteString)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty)
    }

    /// `openIdOverride` patches a discovered document exactly once across repeated
    /// `oidcInitialize()` calls, and discovery itself runs only once.
    func testOpenIdOverrideAppliedOnceToDiscoveredOpenId() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.deviceAuthorizationEndpoint = MockAPIEndpoint.deviceAuthorization.url.absoluteString
        }

        try await oidcClientConfig.oidcInitialize()
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "openIdOverride must be applied exactly once")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, MockAPIEndpoint.deviceAuthorization.url.absoluteString)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1, "Discovery must run only once")
    }

    /// A clone of an already-initialised configuration carries the "override applied" state, so
    /// `OidcModule`'s `success` hook cannot re-run a caller's closure on a patched document.
    func testCloneDoesNotReapplyOpenIdOverride() async throws {
        MockURLProtocol.requestHistory.removeAll()
        oidcClientConfig.discoveryEndpoint = ""
        oidcClientConfig.openId = makeOpenIdConfiguration()

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.tokenEndpoint += "?applied=\(counter.count)"
        }

        try await oidcClientConfig.oidcInitialize()
        XCTAssertEqual(counter.count, 1)

        let cloned = oidcClientConfig.clone()
        try await cloned.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "clone() must not re-run openIdOverride")
        XCTAssertEqual(cloned.openId?.tokenEndpoint, oidcClientConfig.openId?.tokenEndpoint)
        XCTAssertEqual(cloned.openId?.tokenEndpoint, "\(MockAPIEndpoint.token.url.absoluteString)?applied=1")
    }

    /// Regression guard: with `openId` left `nil`, discovery still runs against `discoveryEndpoint`.
    func testOidcInitializeRunsDiscoveryWhenOpenIdIsNil() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        XCTAssertNil(oidcClientConfig.openId)

        try await oidcClientConfig.oidcInitialize()

        XCTAssertNotNil(oidcClientConfig.openId)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1)
        XCTAssertEqual(MockURLProtocol.requestHistory.first?.url, MockAPIEndpoint.discovery.url)
    }

    // TestRailCase(22081)
    func testClone() {
        oidcClientConfig.refreshThreshold = 100
        oidcClientConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        oidcClientConfig.logger = LogManager.standard
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.discoveryEndpoint = "https://example.com"
        oidcClientConfig.clientId = "clientId"
        oidcClientConfig.scopes.insert("openid")
        oidcClientConfig.redirectUri = "http://localhost/callback"
        oidcClientConfig.loginHint = "loginHint"
        oidcClientConfig.nonce = "nonce"
        oidcClientConfig.display = "display"
        oidcClientConfig.prompt = "prompt"
        oidcClientConfig.uiLocales = "uiLocales"
        oidcClientConfig.acrValues = "acrValues"
        oidcClientConfig.additionalParameters = ["param": "value"]
        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        oidcClientConfig.par = true
        
        let clonedConfig = oidcClientConfig.clone()
        
        XCTAssertEqual(oidcClientConfig.openId.debugDescription, clonedConfig.openId.debugDescription)
        XCTAssertEqual(oidcClientConfig.refreshThreshold, clonedConfig.refreshThreshold)
        XCTAssertEqual(oidcClientConfig.agent.debugDescription, clonedConfig.agent.debugDescription)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, clonedConfig.discoveryEndpoint)
        XCTAssertEqual(oidcClientConfig.clientId, clonedConfig.clientId)
        XCTAssertEqual(oidcClientConfig.scopes, clonedConfig.scopes)
        XCTAssertEqual(oidcClientConfig.redirectUri, clonedConfig.redirectUri)
        XCTAssertEqual(oidcClientConfig.loginHint, clonedConfig.loginHint)
        XCTAssertEqual(oidcClientConfig.nonce, clonedConfig.nonce)
        XCTAssertEqual(oidcClientConfig.display, clonedConfig.display)
        XCTAssertEqual(oidcClientConfig.prompt, clonedConfig.prompt)
        XCTAssertEqual(oidcClientConfig.uiLocales, clonedConfig.uiLocales)
        XCTAssertEqual(oidcClientConfig.acrValues, clonedConfig.acrValues)
        XCTAssertEqual(oidcClientConfig.additionalParameters, clonedConfig.additionalParameters)
        XCTAssertEqual(oidcClientConfig.httpClient.debugDescription, clonedConfig.httpClient.debugDescription)
        XCTAssertEqual(oidcClientConfig.par, clonedConfig.par)
    }
    
    // TestRailCase(24719)
    func testUpdate() {
        let otherConfig = OidcClientConfig()
        otherConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        otherConfig.logger = LogManager.standard
        otherConfig.storage = MockStorage<Token>()
        otherConfig.discoveryEndpoint = "https://example.com"
        otherConfig.clientId = "clientId"
        otherConfig.scopes.insert("openid")
        otherConfig.redirectUri = "http://localhost/callback"
        otherConfig.loginHint = "loginHint"
        otherConfig.nonce = "nonce"
        otherConfig.display = "display"
        otherConfig.prompt = "prompt"
        otherConfig.uiLocales = "uiLocales"
        otherConfig.acrValues = "acrValues"
        otherConfig.additionalParameters = ["param": "value"]
        otherConfig.httpClient = MockURLProtocol.makeClient()
        otherConfig.par = true
        
        oidcClientConfig.update(with: otherConfig)
        
        XCTAssertEqual(otherConfig.openId.debugDescription, oidcClientConfig.openId.debugDescription)
        XCTAssertEqual(otherConfig.agent.debugDescription, oidcClientConfig.agent.debugDescription)
        XCTAssertEqual(otherConfig.discoveryEndpoint, oidcClientConfig.discoveryEndpoint)
        XCTAssertEqual(otherConfig.clientId, oidcClientConfig.clientId)
        XCTAssertEqual(otherConfig.scopes, oidcClientConfig.scopes)
        XCTAssertEqual(otherConfig.redirectUri, oidcClientConfig.redirectUri)
        XCTAssertEqual(otherConfig.loginHint, oidcClientConfig.loginHint)
        XCTAssertEqual(otherConfig.nonce, oidcClientConfig.nonce)
        XCTAssertEqual(otherConfig.display, oidcClientConfig.display)
        XCTAssertEqual(otherConfig.prompt, oidcClientConfig.prompt)
        XCTAssertEqual(otherConfig.uiLocales, oidcClientConfig.uiLocales)
        XCTAssertEqual(otherConfig.acrValues, oidcClientConfig.acrValues)
        XCTAssertEqual(otherConfig.additionalParameters, oidcClientConfig.additionalParameters)
        XCTAssertEqual(otherConfig.httpClient.debugDescription, oidcClientConfig.httpClient.debugDescription)
        XCTAssertEqual(otherConfig.par, oidcClientConfig.par)
    }
}

/// Reference-typed counter so `openIdOverride` closures can record how often they ran.
final class CallCounter: @unchecked Sendable {
    var count = 0
}

// Mock classes for AgentDelegateProtocol, Agent, HttpClient, etc.
class MockAgent: Agent, @unchecked Sendable {
    func config() -> () -> T {
        return {}
    }
    
    func endSession(oidcConfig: PingOidc.OidcConfig<T>, idToken: String) async throws -> Bool {
        let params = [
            "client_id": oidcConfig.oidcClientConfig.clientId,
            "id_token_hint": idToken
        ]
        
        guard let httpClient = oidcConfig.oidcClientConfig.httpClient else {
            XCTFail("httpClient should not be nil")
            return false
        }
        
        _ = try await httpClient.request { request in
            request.url = MockAPIEndpoint.endSession.url.absoluteString
            request.form(parameters: params)
        }
        
        return true
    }
    
    func authorize(oidcConfig: PingOidc.OidcConfig<T>) async throws -> PingOidc.AuthCode {
        return AuthCode(code: "TestAgent", codeVerifier: "codeVerifier")
    }
    
    typealias T = Void
}
