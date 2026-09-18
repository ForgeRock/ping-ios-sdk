//
//  AgentTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 - 2026 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingStorage
@testable import PingNetwork

final class AgentTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var agent: CreateAgent!
    var session: MockSession!
    var pkce: Pkce!
    var httpClient: MockHttpClient!
    var oidcConfig: OidcConfig<Void>!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        session = MockSession()
        pkce = Pkce.generate()
        agent = CreateAgent(session: session, pkce: pkce, cookieName: "iPlanetDirectoryPro")
        
        httpClient = MockHttpClient()
        let clientConfig = OidcClientConfig()
        clientConfig.httpClient = httpClient
        clientConfig.clientId = "test-client"
        clientConfig.redirectUri = "https://example.com/callback"
        clientConfig.scopes = ["openid", "profile"]
        clientConfig.openId = OpenIdConfiguration(authorizationEndpoint: "https://auth.example.com/authorize", tokenEndpoint: "https://auth.example.com/token", userinfoEndpoint: "https://auth.example.com/userInfo", endSessionEndpoint: "https://auth.example.com/endSession", revocationEndpoint: "https://auth.example.com/revoke", pingEndsessionEndpoint: "https://auth.example.com/authorized/ping/endSession")
        oidcConfig = OidcConfig(oidcClientConfig: clientConfig, config: ())
    }
    
    // MARK: - Tests
    
    func testInitialization() {
        XCTAssertEqual(agent.cookieName, "iPlanetDirectoryPro")
        XCTAssertNotNil(agent.session)
        XCTAssertNotNil(agent.pkce)
        XCTAssertFalse(agent.used)
    }
    
    func testConfig() {
        let config = agent.config()
        // Config should return empty closure
        XCTAssertNoThrow(config())
    }
    
    func testEndSession() async {
        let result = try! await agent.endSession(oidcConfig: oidcConfig, idToken: "test-token")
        XCTAssertTrue(result)
    }
    
    func testAuthorizeWithEmptySession() async throws {
        let emptySession = MockSession(value: "")
        let agent = CreateAgent(session: emptySession, pkce: pkce, cookieName: "iPlanetDirectoryPro")
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for empty session")
        } catch {
            XCTAssertTrue(error is OidcError)
            let oidcError = error as! OidcError
            XCTAssertEqual(oidcError.errorMessage, "Authorization error: Please start Journey to authenticate.")
        }
    }
    
    func testSuccessfulAuthorize() async throws {
        let successResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/callback?code=test-auth-code"]
        )!
        httpClient.mockResponse = (Data(), successResponse)
        
        let authCode = try await agent.authorize(oidcConfig: oidcConfig)
        
        XCTAssertEqual(authCode.code, "test-auth-code")
        XCTAssertNotNil(authCode.codeVerifier)
        XCTAssertTrue(agent.used)
        
        // Verify request parameters
        guard let request = httpClient.lastRequest else {
            XCTFail("request should not be nil")
            return
        }
        
        guard let urlString = request.url else {
            XCTFail("request url should not be nil")
            return
        }
        let url = URL(string: urlString)
        let baseURLString = "\(url?.scheme ?? "")://\(url?.host ?? "")\(url?.path ?? "")"
        XCTAssertEqual(baseURLString, "https://auth.example.com/authorize")
        XCTAssertEqual(request.getHeader(name: "Accept-API-Version"), "resource=2.1, protocol=1.0")
        XCTAssertEqual(request.getHeader(name: "iPlanetDirectoryPro"), "test-session")
    }
    
    func testAuthorizeWithNon302Response() async throws {
        let errorResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        httpClient.mockResponse = (Data("Error".utf8), errorResponse)
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for non-302 response")
        } catch {
            XCTAssertTrue(error is OidcError)
            XCTAssertTrue(error.localizedDescription.contains("API error"))
        }
    }
    
    func testAuthorizeWithInvalidRedirect() async throws {
        let invalidResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/callback"]
        )!
        httpClient.mockResponse = (Data(), invalidResponse)
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for invalid redirect")
        } catch {
            XCTAssertTrue(error is OidcError)
            let oidcError = error as! OidcError
            XCTAssertTrue(oidcError.errorMessage.contains("Code not found in redirect"))
        }
    }
    
    // MARK: - Session Extension Tests
    
    func testSessionAuthCode() {
        let code = "test-code"
        let authCode = session.authCode(pkce: pkce, code: code)
        
        XCTAssertEqual(authCode.code, code)
        XCTAssertEqual(authCode.codeVerifier, pkce.codeVerifier)
    }
    
    func testSessionAuthCodeWithoutPkce() {
        let code = "test-code"
        let authCode = session.authCode(pkce: nil, code: code)

        XCTAssertEqual(authCode.code, code)
        XCTAssertNil(authCode.codeVerifier)
    }

    // MARK: - Blank cookie-name fallback (JourneyConfig.ssoHeaderName)

    /// Regression test: `JourneyConfig.cookie` is a plain `String` defaulting to
    /// `iPlanetDirectoryPro`, but integrators can legitimately set it to `""` (the sample
    /// app's config editor stores `cookieName` as an optional that the sample maps with
    /// `?? ""`). Sending the SSO token under an empty header name is a malformed request —
    /// the server resets the connection (observed as `-1005 The network connection was
    /// lost`) — so `CreateAgent` must normalize a blank name to `iPlanetDirectoryPro`.
    func testCreateAgentBlankCookieNameFallsBackToDefault() {
        let blankAgent = CreateAgent(session: session, pkce: pkce, cookieName: "")
        XCTAssertEqual(blankAgent.cookieName, "iPlanetDirectoryPro")

        let whitespaceAgent = CreateAgent(session: session, pkce: pkce, cookieName: "   ")
        XCTAssertEqual(whitespaceAgent.cookieName, "iPlanetDirectoryPro")

        let explicitAgent = CreateAgent(session: session, pkce: pkce, cookieName: "386c0d288cac4b9")
        XCTAssertEqual(explicitAgent.cookieName, "386c0d288cac4b9", "A non-blank name must be preserved")
    }

    /// The request must carry the SSO token under the fallback header name when the
    /// configured name was blank.
    func testAuthorizeSendsSSOTokenUnderFallbackHeaderName() async throws {
        let successResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/callback?code=test-auth-code"]
        )!
        httpClient.mockResponse = (Data(), successResponse)

        let blankAgent = CreateAgent(session: session, pkce: pkce, cookieName: "")
        _ = try await blankAgent.authorize(oidcConfig: oidcConfig)

        guard let request = httpClient.lastRequest else {
            XCTFail("request should not be nil")
            return
        }
        XCTAssertEqual(request.getHeader(name: "iPlanetDirectoryPro"), "test-session")
        XCTAssertNil(request.getHeader(name: ""), "No header may be sent under an empty name")
    }

    /// `JourneyConfig.ssoHeaderName` mirrors the same fallback at config level.
    func testJourneyConfigSSOHeaderNameFallback() {
        let config = JourneyConfig()
        XCTAssertEqual(config.ssoHeaderName, "iPlanetDirectoryPro")

        config.cookie = "386c0d288cac4b9"
        XCTAssertEqual(config.ssoHeaderName, "386c0d288cac4b9")

        config.cookie = ""
        XCTAssertEqual(config.ssoHeaderName, "iPlanetDirectoryPro")
    }

    // MARK: - journeyUser() fallback agent (DefaultAgent regression)

    /// Regression test: `journeyUser()`'s fallback used to build the `OidcUser` from the
    /// module config as-is, whose initialize step installs `DefaultAgent` — an agent whose
    /// `authorize` ALWAYS throws "No AuthCode is available.". The fallback must instead swap
    /// in a `CreateAgent` bound to the restored session.
    @MainActor
    func testJourneyUserFallbackSwapsInUsableAgent() async throws {
        let journey = Journey.createJourney { journeyConfig in
            journeyConfig.serverUrl = "https://example.com/am"
            journeyConfig.realm = "alpha"
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = "journey-fallback-client"
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "https://example.com/callback"
                oidcValue.openId = OpenIdConfiguration(
                    authorizationEndpoint: "https://auth.example.com/authorize",
                    tokenEndpoint: "https://auth.example.com/token",
                    userinfoEndpoint: "https://auth.example.com/userInfo",
                    endSessionEndpoint: "https://auth.example.com/endSession",
                    revocationEndpoint: "https://auth.example.com/revoke",
                    pingEndsessionEndpoint: "https://auth.example.com/ping/endSession"
                )
            }
        }

        // Initialize explicitly (the pattern the existing JourneyTests use) so all module
        // initialize handlers — SessionModule's, which publishes the SessionConfig — have run.
        try await journey.initialize()
        let sessionConfig = try XCTUnwrap(
            journey.sharedContext.get(key: SharedContext.Keys.sessionConfigKey) as? SessionConfig,
            "SessionConfig must be published after initialize()"
        )
        // Keep the original (keychain) storage so cleanup can clear the persisted slot.
        let originalStorage = sessionConfig.storage
        // Swap in in-memory storage so the test does not read a previously persisted session.
        let memoryStorage = MemoryStorage<SSOTokenImpl>()
        sessionConfig.storage = memoryStorage
        try await memoryStorage.save(item: SSOTokenImpl(
            value: "fallback-session-token",
            successUrl: "/enduser/?realm=/alpha",
            realm: "/alpha"
        ))

        let resolvedUser = await journey.journeyUser()
        let user = try XCTUnwrap(resolvedUser, "A restored session must yield a user")

        // token() must NOT fail with the DefaultAgent's "No AuthCode is available." — with
        // a real CreateAgent installed, the failure (if any) comes from the backchannel
        // authorize exchange itself.
        let result = await user.token()
        guard case .failure(let error) = result else {
            XCTFail("token() against a stub config is not expected to succeed, but must not fail with the DefaultAgent's error")
            return
        }
        XCTAssertFalse(
            error.localizedDescription.contains("No AuthCode is available"),
            "journeyUser()'s fallback must not return a user backed by DefaultAgent (got: \(error.localizedDescription))"
        )

        // Clean up: the test swapped in MemoryStorage AFTER reading the default (keychain)
        // slot, so delete through the ORIGINAL keychain storage to clear the persisted
        // slot — otherwise `testJourneyUserWithOidcConfig` / `...NoUserOrSession` (which
        // rely on a clean default slot) would see this token on the next run.
        try? await originalStorage.delete()
    }
}
