//
//  OidcWebClientJsonConfigE2ETests.swift
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
@testable import PingLogger

/// E2E coverage for the unified JSON configuration factory `OidcWebClient.createOidcWebClient(json:)`.
///
/// Config-level tests validate field parsing, default values, and error cases without making
/// network calls. Live tests run against the AIC test server to verify that a JSON-built
/// OidcWebClient performs OIDC discovery and constructs a well-formed authorize URL.
///
/// The browser step is intercepted by `OidcJsonCapturingBrowser` — no ASWebAuthenticationSession
/// opens — so tests assert on the authorize URL that the SDK *would* open.
@MainActor
final class OidcWebClientJsonConfigE2ETests: XCTestCase {

    private var browser: OidcJsonCapturingBrowser!
    private var aicConfig: OidcE2EConfig!

    override func setUp() async throws {
        try await super.setUp()
        browser = OidcJsonCapturingBrowser()
        BrowserLauncher.currentBrowser = browser
        aicConfig = try OidcE2EConfig("OidcAICConfig")
    }

    override func tearDown() async throws {
        BrowserLauncher.currentBrowser = BrowserLauncher()
        try await super.tearDown()
    }

    // MARK: - JSON fixtures

    private var baseOidcDict: [String: Any] {
        [
            "clientId": aicConfig.clientId,
            "discoveryEndpoint": aicConfig.discoveryEndpoint,
            "scopes": aicConfig.scopes,
            "redirectUri": aicConfig.redirectUri
        ]
    }

    private var minimalJson: [String: Any] {
        ["oidc": baseOidcDict]
    }

    private var fullJson: [String: Any] {
        [
            "timeout": 30000,
            "log": "DEBUG",
            "oidc": [
                "clientId": aicConfig.clientId,
                "discoveryEndpoint": aicConfig.discoveryEndpoint,
                "scopes": aicConfig.scopes,
                "redirectUri": aicConfig.redirectUri,
                "refreshThreshold": 60
            ] as [String: Any]
        ]
    }

    // MARK: - Config parsing: field values

    // Verifies that omitting optional fields produces the documented default timeout of 15s.
    func testMinimalJsonConfig_defaultValues() throws {
        let client = try OidcWebClient.createOidcWebClient(json: minimalJson).get()
        XCTAssertEqual(client.config.timeout, 15.0)
    }

    // Verifies that timeout (ms → seconds) and log level are parsed and applied when the full JSON is provided.
    func testFullJsonConfig_allValuesApplied() throws {
        let client = try OidcWebClient.createOidcWebClient(json: fullJson).get()
        XCTAssertEqual(client.config.timeout, 30.0)
        XCTAssertTrue(client.config.logger is StandardLogger)
    }

    // Verifies that unrecognised keys at the top level and inside the oidc dict are silently ignored.
    func testUnknownFields_areIgnored() {
        var json = minimalJson
        json["unknownTopLevel"] = "should-be-ignored"
        json["serverUrl"] = "https://example.com/am"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc
        XCTAssertNoThrow(try OidcWebClient.createOidcWebClient(json: json).get(),
                         "Unknown fields should be silently ignored")
    }

    // MARK: - Config parsing: missing required fields

    // Verifies that an empty top-level dict (no "oidc" key) returns missingRequiredField("oidc").
    func testMissingOidcDict_returnsConfigError() {
        let result = OidcWebClient.createOidcWebClient(json: [:])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // Verifies that omitting "clientId" from the oidc dict returns missingRequiredField("oidc.clientId").
    func testMissingClientId_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "clientId")
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    // Verifies that omitting "discoveryEndpoint" from the oidc dict returns missingRequiredField("oidc.discoveryEndpoint").
    func testMissingDiscoveryEndpoint_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "discoveryEndpoint")
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    // Verifies that omitting "scopes" from the oidc dict returns missingRequiredField("oidc.scopes").
    func testMissingScopes_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "scopes")
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that omitting "redirectUri" from the oidc dict returns missingRequiredField("oidc.redirectUri").
    func testMissingRedirectUri_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "redirectUri")
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    // MARK: - Config parsing: wrong types

    // Verifies that a non-numeric "timeout" value returns invalidType("timeout").
    func testTimeoutWrongType_returnsConfigError() {
        var json = minimalJson
        json["timeout"] = "not-a-number"
        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)")
            return
        }
        XCTAssertEqual(field, "timeout")
    }

    // Verifies that a non-dict "oidc" value returns invalidType("oidc").
    func testOidcWrongType_returnsConfigError() {
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": "not-an-object"])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // Verifies that a non-string-array "scopes" value returns invalidType("oidc.scopes").
    func testScopesWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["scopes"] = [1, 2, 3]
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that a non-numeric "refreshThreshold" value returns invalidType("oidc.refreshThreshold").
    func testRefreshThresholdWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["refreshThreshold"] = "not-a-number"
        let result = OidcWebClient.createOidcWebClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.refreshThreshold), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.refreshThreshold")
    }

    // MARK: - Live network tests

    // Triggers OIDC discovery via a JSON-built client and asserts the resulting authorize URL uses the AIC server and contains required PKCE parameters.
    func testOpenIdEndpointsAreLoaded() async throws {
        let web = try OidcWebClient.createOidcWebClient(json: minimalJson).get()
        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let authorizeURL = try XCTUnwrap(browser.launchedURL,
                                         "Browser was not launched — discovery may have failed")
        let expectedHost = URL(string: aicConfig.discoveryEndpoint)?.host
        XCTAssertNotNil(expectedHost, "Could not derive host from discoveryEndpoint")
        XCTAssertEqual(authorizeURL.host, expectedHost,
                       "Authorize URL must use the AIC server returned by discovery, got: \(authorizeURL)")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("client_id=\(aicConfig.clientId)"))
        XCTAssertTrue(query.contains("response_type=code"))
        XCTAssertTrue(query.contains("code_challenge="))
    }

    // Builds a client from minimal JSON and asserts the authorize URL contains correct PKCE and OAuth parameters without PAR.
    func testLogin_withMinimalJsonConfig_succeeds() async throws {
        let web = try OidcWebClient.createOidcWebClient(json: minimalJson).get()
        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("client_id=\(aicConfig.clientId)"))
        XCTAssertTrue(query.contains("response_type=code"))
        XCTAssertTrue(query.contains("code_challenge="))
        XCTAssertTrue(query.contains("code_challenge_method=S256"))
        XCTAssertTrue(query.contains("state="))
        XCTAssertFalse(query.contains("request_uri="), "request_uri must not appear without PAR")
    }

    // Builds a client from full JSON (timeout, log level) and verifies the authorize URL is constructed correctly.
    func testLogin_withFullJsonConfig_succeeds() async throws {
        let web = try OidcWebClient.createOidcWebClient(json: fullJson).get()
        do { _ = try await web.authorize() } catch { /* token exchange fails with fake code — expected */ }

        let authorizeURL = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        let query = authorizeURL.absoluteString
        XCTAssertTrue(query.contains("client_id=\(aicConfig.clientId)"))
        XCTAssertTrue(query.contains("response_type=code"))
        XCTAssertTrue(query.contains("code_challenge="))
    }

    // Builds a client from JSON with unrecognised keys and verifies the browser is still launched (flow not broken by unknown fields).
    func testLogin_withUnknownJsonFields_succeeds() async throws {
        var json = minimalJson
        json["unknownTopLevel"] = "ignored"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let web = try OidcWebClient.createOidcWebClient(json: json).get()
        do { _ = try await web.authorize() } catch { /* expected */ }

        XCTAssertNotNil(browser.launchedURL,
                        "Browser should have been launched — unknown fields must not break the flow")
    }
}

// MARK: - OidcJsonCapturingBrowser

/// Intercepts `BrowserLauncher.currentBrowser.launch(...)` and records the URL.
/// Returns a fake callback URL — the token exchange step will fail, but that's acceptable
/// for tests that only care about the authorize URL shape.
private final class OidcJsonCapturingBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var launchedURL: URL?
    var isInProgress: Bool = false
    private let callbackURL = URL(string: "frauth://com.forgerock.ios.frexample?code=fake-code&state=fake")!

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
