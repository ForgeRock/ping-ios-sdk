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
    
    func testOidcInitializeSkipsDiscoveryWhenOpenIdPreset() async throws {
        let presetOpenId = OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString
        )
        oidcClientConfig.openId = presetOpenId

        MockURLProtocol.requestHandler = { request in
            XCTFail("Discovery network call should not be made when openId is pre-set")
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(presetOpenId.authorizationEndpoint, oidcClientConfig.openId?.authorizationEndpoint)
        XCTAssertEqual(presetOpenId.tokenEndpoint, oidcClientConfig.openId?.tokenEndpoint)
        XCTAssertEqual(presetOpenId.userinfoEndpoint, oidcClientConfig.openId?.userinfoEndpoint)
        XCTAssertEqual(presetOpenId.endSessionEndpoint, oidcClientConfig.openId?.endSessionEndpoint)
        XCTAssertEqual(presetOpenId.revocationEndpoint, oidcClientConfig.openId?.revocationEndpoint)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No discovery network call should be recorded when openId is pre-set")
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

    func testOidcInitializeThrowsConfigurationErrorWhenUnconfigured() async throws {
        let unconfigured = OidcClientConfig()
        unconfigured.storage = MockStorage<Token>()
        // discoveryEndpoint defaults to "" and openId defaults to nil — fully unconfigured.

        do {
            try await unconfigured.oidcInitialize()
            XCTFail("Expected oidcInitialize() to throw when neither openId nor discoveryEndpoint is configured")
        } catch let error as OidcError {
            guard case .configurationError = error else {
                XCTFail("Expected OidcError.configurationError, got \(error)")
                return
            }
        }
        XCTAssertNil(unconfigured.openId, "A failed initialization must leave openId nil so a later call can retry")
    }

    func testApplyJsonReconfigurationReplacesOverrideWithoutStackingOrStaleDocument() throws {
        let baseJson: [String: Any] = [
            "clientId": "clientId",
            "redirectUri": "http://localhost/callback",
            "scopes": ["openid"],
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString
        ]

        var jsonWithOverrideA = baseJson
        jsonWithOverrideA["openId"] = ["tokenEndpoint": "https://a.example.com/token", "userinfoEndpoint": "https://a.example.com/userinfo"]
        try oidcClientConfig.apply(json: jsonWithOverrideA)

        // Simulate a completed discovery + override application, as oidcInitialize() would do.
        oidcClientConfig.openId = OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString
        )

        // Reconfigure: the new override only patches tokenEndpoint, no longer touches userinfoEndpoint.
        var jsonWithOverrideB = baseJson
        jsonWithOverrideB["openId"] = ["tokenEndpoint": "https://b.example.com/token"]
        try oidcClientConfig.apply(json: jsonWithOverrideB)

        XCTAssertNil(oidcClientConfig.openId, "apply(json:) must invalidate a previously-discovered document on reconfiguration so oidcInitialize() rediscovers")

        var fresh = OpenIdConfiguration(
            authorizationEndpoint: "https://discovered2.example.com/authorize",
            tokenEndpoint: "https://discovered2.example.com/token",
            userinfoEndpoint: "https://discovered2.example.com/userinfo",
            endSessionEndpoint: "https://discovered2.example.com/endsession",
            revocationEndpoint: "https://discovered2.example.com/revoke"
        )
        oidcClientConfig.openIdOverride?(&fresh)

        XCTAssertEqual(fresh.tokenEndpoint, "https://b.example.com/token", "The new (B) override must apply")
        XCTAssertEqual(fresh.userinfoEndpoint, "https://discovered2.example.com/userinfo", "A's userinfoEndpoint override must not leak into B's configuration — the JSON layer must replace wholesale, not stack")
    }

    func testApplyJsonProgrammaticOverrideComposesWithJsonDerivedOverride() throws {
        oidcClientConfig.openIdOverride = { openId in
            openId.deviceAuthorizationEndpoint = "https://programmatic.example.com/device"
        }

        let json: [String: Any] = [
            "clientId": "clientId",
            "redirectUri": "http://localhost/callback",
            "scopes": ["openid"],
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString,
            "openId": ["tokenEndpoint": "https://json.example.com/token"]
        ]
        try oidcClientConfig.apply(json: json)

        var discovered = OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString
        )
        oidcClientConfig.openIdOverride?(&discovered)

        XCTAssertEqual(discovered.deviceAuthorizationEndpoint, "https://programmatic.example.com/device", "Programmatic override must still run")
        XCTAssertEqual(discovered.tokenEndpoint, "https://json.example.com/token", "JSON-derived override must also run, applied after the programmatic one")
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
        oidcClientConfig.openIdOverride = { openId in
            openId.deviceAuthorizationEndpoint = "https://programmatic.example.com/device"
        }

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

        // The programmatic override layer must survive the clone.
        var probe = OpenIdConfiguration(
            authorizationEndpoint: "https://p.example.com/authorize",
            tokenEndpoint: "https://p.example.com/token",
            userinfoEndpoint: "https://p.example.com/userinfo",
            endSessionEndpoint: "https://p.example.com/endsession",
            revocationEndpoint: "https://p.example.com/revoke"
        )
        clonedConfig.openIdOverride?(&probe)
        XCTAssertEqual(probe.deviceAuthorizationEndpoint, "https://programmatic.example.com/device", "clone() must carry over the programmatic override layer")
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

    // MARK: - Concurrent initialization coordination

    func testConcurrentOidcInitializeCoalescesIntoOneDiscoveryCall() async throws {
        let discoveryRequestCount = MockURLProtocol.requestHistory.count
        MockURLProtocol.requestHandler = { request in
            // Small blocking delay so concurrent callers genuinely overlap while the first
            // discovery is in flight (the handler runs on a URL-loading thread, not the caller's).
            Thread.sleep(forTimeInterval: 0.1)
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable [weak oidcClientConfig] in
                    try await oidcClientConfig?.oidcInitialize()
                }
            }
            try await group.waitForAll()
        }

        let newRequests = MockURLProtocol.requestHistory.count - discoveryRequestCount
        XCTAssertEqual(newRequests, 1, "Concurrent oidcInitialize() calls must coalesce into exactly one discovery request, got \(newRequests)")
        XCTAssertNotNil(oidcClientConfig.openId)
    }

    func testSharedInitializationFailureRetriesFresh() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
        }

        do {
            try await oidcClientConfig.oidcInitialize()
            XCTFail("Expected the first initialization to fail with a 500")
        } catch { /* expected */ }
        XCTAssertNil(oidcClientConfig.openId)

        // The in-flight marker must have been cleared by the failed task itself, so the retry
        // issues a genuinely fresh discovery instead of rejoining the (already-failed) task.
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        try await oidcClientConfig.oidcInitialize()
        XCTAssertNotNil(oidcClientConfig.openId, "A call after a failed initialization must start a fresh attempt, not rejoin the failed task")
    }

    func testOverrideIsAppliedExactlyOncePerMaterializedDocument() async throws {
        var applicationCount = 0
        // Non-idempotent override: appends to the endpoint each time it runs.
        oidcClientConfig.openIdOverride = { openId in
            applicationCount += 1
            openId.deviceAuthorizationEndpoint = "https://example.com/device/\(applicationCount)"
        }

        try await oidcClientConfig.oidcInitialize()
        XCTAssertEqual(applicationCount, 1, "Override must run once on first initialization")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "https://example.com/device/1")

        // Re-entrant calls must not re-run the override against the same document.
        try await oidcClientConfig.oidcInitialize()
        try await oidcClientConfig.oidcInitialize()
        XCTAssertEqual(applicationCount, 1, "Re-entrant oidcInitialize() calls must never re-run the override against the same document")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "https://example.com/device/1")

        // Reconfiguring via apply(json:) resets the marker: the override runs once against the
        // next materialized document.
        try oidcClientConfig.apply(json: [
            "clientId": "clientId",
            "redirectUri": "http://localhost/callback",
            "scopes": ["openid"],
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString
        ])
        try await oidcClientConfig.oidcInitialize()
        XCTAssertEqual(applicationCount, 2, "apply(json:) must reset the once-per-document marker so the override runs against the next materialized document")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "https://example.com/device/2")
    }

    func testCloneAndUpdateCarryOverProgrammaticOverrideLayer() {
        oidcClientConfig.openIdOverride = { openId in
            openId.deviceAuthorizationEndpoint = "https://programmatic.example.com/device"
        }

        // clone() carries over the programmatic override layer.
        let cloned = oidcClientConfig.clone()
        var probeForClone = Self.probeConfiguration()
        cloned.openIdOverride?(&probeForClone)
        XCTAssertEqual(probeForClone.deviceAuthorizationEndpoint, "https://programmatic.example.com/device")

        // update(with:) copies the other configuration's programmatic override layer.
        let other = OidcClientConfig()
        other.openIdOverride = { openId in
            openId.deviceAuthorizationEndpoint = "https://other.example.com/device"
        }
        oidcClientConfig.update(with: other)
        var probeForUpdate = Self.probeConfiguration()
        oidcClientConfig.openIdOverride?(&probeForUpdate)
        XCTAssertEqual(probeForUpdate.deviceAuthorizationEndpoint, "https://other.example.com/device", "update(with:) must copy the other configuration's programmatic override layer")
    }

    private static func probeConfiguration() -> OpenIdConfiguration {
        OpenIdConfiguration(
            authorizationEndpoint: "https://p.example.com/authorize",
            tokenEndpoint: "https://p.example.com/token",
            userinfoEndpoint: "https://p.example.com/userinfo",
            endSessionEndpoint: "https://p.example.com/endsession",
            revocationEndpoint: "https://p.example.com/revoke"
        )
    }
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
