//
//  OidcWebClientE2ETests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
@testable import PingBrowser
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage

/// Real-server E2E tests for `OidcWebClient` PAR (RFC 9126).
///
/// Discovery and PAR endpoint calls hit the real test server.  The browser step
/// is intercepted by `CapturingBrowser` — no ASWebAuthenticationSession opens —
/// so the test asserts on the authorize URL that the SDK *would* open.
///
/// Server configuration is loaded from JSON files in `integration tests/Config/`:
/// - `OidcAICConfig.json`     — AIC (openam-sdks.forgeblocks.com)
/// - `OidcPingOneConfig.json` — PingOne (auth.pingone.ca, DaVinci)
@MainActor
final class OidcWebClientE2ETests: XCTestCase {

    private var browser: CapturingBrowser!
    private var recorder: RequestRecorder!

    private var aicConfig: OidcE2EConfig!
    private var pingOneConfig: OidcE2EConfig!

    override func setUp() async throws {
        try await super.setUp()
        browser = CapturingBrowser()
        recorder = RequestRecorder()
        BrowserLauncher.currentBrowser = browser
        aicConfig = try OidcE2EConfig("OidcAICConfig")
        pingOneConfig = try OidcE2EConfig("OidcPingOneConfig")
    }

    override func tearDown() async throws {
        BrowserLauncher.currentBrowser = BrowserLauncher()
        try await super.tearDown()
    }

    // MARK: - AIC (Journey server)

    func testOidcWebClientAICWithoutPAR() async throws {
        let web = makeWebClient(config: aicConfig, additionalParameters: ["foo": "bar"], par: false)

        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertTrue(parCalls.isEmpty, "Expected no PAR call when par=false; got \(parCalls.count)")

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("client_id=\(aicConfig.clientId)"))
        XCTAssertTrue(query.contains("response_type=code"))
        XCTAssertTrue(query.contains("code_challenge="))
        XCTAssertTrue(query.contains("code_challenge_method=S256"))
        XCTAssertTrue(query.contains("state="))
        XCTAssertFalse(query.contains("request_uri="), "request_uri must not appear without PAR")
        XCTAssertTrue(query.contains("foo=bar"), "additionalParameters should be in the authorize URL")
    }

    func testOidcWebClientAICWithPAR() async throws {
        let web = makeWebClient(config: aicConfig, additionalParameters: ["foo": "bar"], par: true)

        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertEqual(parCalls.count, 1, "Expected exactly one PAR request")
        let parReq = parCalls[0]
        XCTAssertEqual(parReq.method, "POST")

        let parFields = parReq.formFields()
        for field in ["client_id", "response_type", "scope", "redirect_uri",
                       "code_challenge", "code_challenge_method", "state"] {
            XCTAssertNotNil(parFields[field], "PAR body must contain \(field)")
        }
        XCTAssertEqual(parFields["client_id"], aicConfig.clientId)
        XCTAssertEqual(parFields["response_type"], "code")
        XCTAssertEqual(parFields["foo"], "bar", "additionalParameters should be in the PAR body")

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("request_uri="), "request_uri must appear in authorize URL")
        XCTAssertTrue(query.contains("client_id=\(aicConfig.clientId)"))
        for forbidden in ["scope=", "redirect_uri=", "code_challenge=", "code_challenge_method="] {
            XCTAssertFalse(query.contains(forbidden),
                            "\(forbidden) must not appear in authorize URL when PAR is enabled")
        }
    }

    // MARK: - PingOne (DaVinci server)

    func testOidcWebClientPingOneWithoutPAR() async throws {
        let web = makeWebClient(config: pingOneConfig, additionalParameters: ["foo": "bar"], par: false)

        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertTrue(parCalls.isEmpty, "Expected no PAR call when par=false; got \(parCalls.count)")

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("client_id=\(pingOneConfig.clientId)"))
        XCTAssertTrue(query.contains("response_type=code"))
        XCTAssertTrue(query.contains("code_challenge="))
        XCTAssertTrue(query.contains("code_challenge_method=S256"))
        XCTAssertTrue(query.contains("state="))
        XCTAssertFalse(query.contains("request_uri="), "request_uri must not appear without PAR")
        XCTAssertTrue(query.contains("foo=bar"), "additionalParameters should be in the authorize URL")
        XCTAssertTrue(query.contains("response_mode=\(pingOneConfig.responseMode)"),
                      "response_mode must be in authorize URL for PingOne DaVinci")
    }

    func testOidcWebClientPingOneWithPAR() async throws {
        let web = makeWebClient(config: pingOneConfig, additionalParameters: ["foo": "bar"], par: true)

        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertEqual(parCalls.count, 1, "Expected exactly one PAR request")
        let parReq = parCalls[0]
        XCTAssertEqual(parReq.method, "POST")

        let parFields = parReq.formFields()
        for field in ["client_id", "response_type", "scope", "redirect_uri",
                       "code_challenge", "code_challenge_method", "state"] {
            XCTAssertNotNil(parFields[field], "PAR body must contain \(field)")
        }
        XCTAssertEqual(parFields["client_id"], pingOneConfig.clientId)
        XCTAssertEqual(parFields["response_type"], "code")
        XCTAssertEqual(parFields["foo"], "bar", "additionalParameters should be in the PAR body")
        XCTAssertEqual(parFields["response_mode"], pingOneConfig.responseMode,
                       "response_mode must be in PAR body for PingOne DaVinci")

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("request_uri="), "request_uri must appear in authorize URL")
        XCTAssertTrue(query.contains("client_id=\(pingOneConfig.clientId)"))
        for forbidden in ["scope=", "redirect_uri=", "code_challenge=", "code_challenge_method="] {
            XCTAssertFalse(query.contains(forbidden),
                            "\(forbidden) must not appear in authorize URL when PAR is enabled")
        }
    }

    // MARK: - Helper

    private func makeWebClient(config: OidcE2EConfig,
                                additionalParameters: [String: String],
                                par: Bool) -> OidcWebClient {
        let rec = self.recorder!
        var merged = additionalParameters
        if !config.responseMode.isEmpty {
            merged["response_mode"] = config.responseMode
        }
        let extraParams = merged
        return OidcWebClient.createOidcWebClient { webConfig in
            webConfig.httpClient = RecordingHttpClient(recorder: rec)
            webConfig.module(PingOidc.OidcModule.config) { oidc in
                oidc.clientId = config.clientId
                oidc.scopes = Set(config.scopes)
                oidc.redirectUri = config.redirectUri
                oidc.discoveryEndpoint = config.discoveryEndpoint
                if !config.acrValues.isEmpty {
                    oidc.acrValues = config.acrValues
                }
                oidc.additionalParameters = extraParams
                oidc.storage = MockStorage<Token>()
                oidc.par = par
            }
        }
    }
}

// MARK: - CapturingBrowser

/// Intercepts `BrowserLauncher.currentBrowser.launch(...)` and records the URL.
/// Returns a fake callback URL — the token step will fail, but that's acceptable
/// for tests that only care about the authorize URL shape.
private final class CapturingBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var launchedURL: URL?
    var isInProgress: Bool = false
    private let callbackURL: URL = URL(string: "frauth://com.forgerock.ios.frexample?code=fake-code&state=fake")!

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        logger: PingLogger.Logger
    ) async throws -> URL {
        launchedURL = url
        return callbackURL
    }

    func reset() {}
    func handleAppActivation() {}
}
